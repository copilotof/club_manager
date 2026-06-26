// lib/core/services/notification_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/repositories/belt_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../injection/dependency_injection.dart';

/// خدمة الإشعارات - مسؤولة عن إنشاء التنبيهات الأربعة
class NotificationService {
  late NotificationRepository _notificationRepo;

  NotificationService() {
    _notificationRepo = NotificationRepository(localDb: getIt());
  }

  /// جلب إعدادات التنبيهات من SharedPreferences
  Future<Map<String, int>> _getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'recurrentAbsenceThreshold':
          prefs.getInt('recurrent_absence_threshold') ?? 3,
      'competitionReminderDays': prefs.getInt('competition_reminder_days') ?? 7,
      'beltPromotionMonths': prefs.getInt('belt_promotion_months') ?? 3,
      'paymentDelayMonths': prefs.getInt('payment_delay_months') ?? 2,
    };
  }

  // ==================== 1. تنبيه الغياب المتكرر ====================
  Future<void> checkRecurrentAbsences() async {
    try {
      final settings = await _getNotificationSettings();
      final threshold = settings['recurrentAbsenceThreshold']!;

      final attendanceRepo = AttendanceRepository(
        localDb: getIt(),
        remoteApi: getIt(),
        connectivity: getIt(),
      );
      final studentRepo =
          StudentRepository(localDb: getIt(), remoteApi: getIt());

      final students = await studentRepo.getAllStudents();

      for (var student in students) {
        final records = await attendanceRepo.getStudentAttendance(
          studentId: student.id!,
          limit: threshold,
        );

        // حساب عدد الغيابات المتتالية
        int consecutiveAbsences = 0;
        for (var record in records) {
          if (!record.isPresent) {
            consecutiveAbsences++;
          } else {
            break;
          }
        }

        if (consecutiveAbsences >= threshold) {
          await _createNotification(
            type: 'attendance',
            title: '⚠️ غياب متكرر للطالب ${student.fullName}',
            message:
                'تغيب الطالب ${student.fullName} عن $consecutiveAbsences حصص متتالية',
            studentId: student.id,
            priority: 1,
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص الغياب المتكرر: $e');
    }
  }

  // ==================== 2. تنبيه البطولات القادمة ====================
  Future<void> checkUpcomingCompetitions() async {
    try {
      final settings = await _getNotificationSettings();
      final days = settings['competitionReminderDays']!;

      final competitionRepo = CompetitionRepository(localDb: getIt());
      final competitions = await competitionRepo.getUpcomingCompetitions();

      for (var competition in competitions) {
        final daysLeft =
            competition.startDate.difference(DateTime.now()).inDays;

        if (daysLeft == days) {
          await _createNotification(
            type: 'competition',
            title: '🏆 بطولة قادمة: ${competition.name}',
            message:
                'تبدأ البطولة بعد $daysLeft يوماً في ${competition.location}',
            relatedId: competition.id,
            priority: 1,
            actionUrl: '/competition/${competition.id}',
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص البطولات القادمة: $e');
    }
  }

  // ==================== 3. تنبيه ترقية الحزام ====================
  Future<void> checkBeltPromotions() async {
    try {
      final settings = await _getNotificationSettings();
      final months = settings['beltPromotionMonths']!;

      final beltRepo = BeltRepository(localDb: getIt());
      final studentRepo =
          StudentRepository(localDb: getIt(), remoteApi: getIt());

      final students = await studentRepo.getAllStudents();

      for (var student in students) {
        final latestBelt = await beltRepo.getLatestBelt(student.id!);

        if (latestBelt != null) {
          final monthsSince =
              DateTime.now().difference(latestBelt.dateAchieved).inDays ~/ 30;

          if (monthsSince >= months) {
            await _createNotification(
              type: 'belt',
              title: '🥋 ترقية حزام للطالب ${student.fullName}',
              message:
                  'مر ${monthsSince} شهراً على آخر ترقية للطالب ${student.fullName} (${latestBelt.beltColor})',
              studentId: student.id,
              relatedId: latestBelt.id,
              priority: 1,
            );
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص ترقيات الأحزمة: $e');
    }
  }

  // ==================== 4. تنبيه تأخر الدفع ====================
  Future<void> checkPaymentDelays() async {
    try {
      final settings = await _getNotificationSettings();
      final delayMonths = settings['paymentDelayMonths']!;

      final paymentRepo = PaymentRepository(localDb: getIt());
      final studentRepo =
          StudentRepository(localDb: getIt(), remoteApi: getIt());
      final students = await studentRepo.getAllStudents();

      final prefs = await SharedPreferences.getInstance();
      final monthlyFee = prefs.getDouble('monthly_fee') ?? 2000;

      for (var student in students) {
        int unpaidMonths = 0;

        // فحص الأشهر السابقة
        for (int i = 1; i <= delayMonths; i++) {
          final month = DateTime.now().month - i;
          final year = DateTime.now().year;
          final targetMonth = month <= 0 ? month + 12 : month;
          final targetYear = month <= 0 ? year - 1 : year;

          final paid = await paymentRepo.getTotalPaidForTarget(
            studentId: student.id!,
            paymentType: 'monthly',
            targetMonth: targetMonth,
            targetYear: targetYear,
          );

          if (paid < monthlyFee) {
            unpaidMonths++;
          }
        }

        if (unpaidMonths >= delayMonths) {
          final totalDebt = await paymentRepo.getTotalPaidForTarget(
            studentId: student.id!,
            paymentType: 'monthly',
            targetMonth: DateTime.now().month - 1,
            targetYear: DateTime.now().year,
          );

          await _createNotification(
            type: 'payment',
            title: '💳 تأخر دفع مستحقات الطالب ${student.fullName}',
            message:
                'تأخر الطالب ${student.fullName} عن دفع مستحقات $delayMonths أشهر متتالية',
            studentId: student.id,
            priority: 2,
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص تأخر الدفع: $e');
    }
  }

  // ==================== إنشاء إشعار ====================
  Future<void> _createNotification({
    required String type,
    required String title,
    required String message,
    int? studentId,
    int? relatedId,
    int priority = 0,
    String? actionUrl,
  }) async {
    // التحقق من وجود إشعار مكرر خلال 24 ساعة
    final existing = await _notificationRepo.getAllNotifications();
    final duplicate = existing.any((n) =>
        n.type == type &&
        n.studentId == studentId &&
        n.title == title &&
        n.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1))));

    if (duplicate) return;

    final notification = NotificationModel(
      type: type,
      title: title,
      message: message,
      studentId: studentId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: priority,
      actionUrl: actionUrl,
    );

    await _notificationRepo.addNotification(notification);
    print('✅ تم إنشاء إشعار: $title');
  }

  // ==================== تشغيل جميع الفحوصات ====================
  Future<void> runAllChecks() async {
    await checkRecurrentAbsences();
    await checkUpcomingCompetitions();
    await checkBeltPromotions();
    await checkPaymentDelays();
  }
}

/* // lib/core/services/notification_service.dart
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../injection/dependency_injection.dart';

/// خدمة الإشعارات - مسؤولة عن إنشاء الإشعارات تلقائياً عند وقوع أحداث
class NotificationService {
  late NotificationRepository _repository;

  NotificationService() {
    _repository = NotificationRepository(localDb: getIt());
  }

  /// إنشاء إشعار دفع مالي
  Future<void> createPaymentNotification({
    required int studentId,
    required String title,
    required String message,
    int? relatedId,
  }) async {
    final notification = NotificationModel(
      type: 'payment',
      title: title,
      message: message,
      studentId: studentId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
    );
    await _repository.addNotification(notification);
  }

  /// إنشاء إشعار حضور وغياب
  Future<void> createAttendanceNotification({
    required int studentId,
    required String title,
    required String message,
    int? relatedId,
  }) async {
    final notification = NotificationModel(
      type: 'attendance',
      title: title,
      message: message,
      studentId: studentId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
    );
    await _repository.addNotification(notification);
  }

  /// إنشاء إشعار بطولة
  Future<void> createCompetitionNotification({
    required String title,
    required String message,
    int? studentId,
    int? relatedId,
  }) async {
    final notification = NotificationModel(
      type: 'competition',
      title: title,
      message: message,
      studentId: studentId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
    );
    await _repository.addNotification(notification);
  }

  /// إنشاء إشعار ترقية حزام
  Future<void> createBeltNotification({
    required int studentId,
    required String title,
    required String message,
    int? relatedId,
  }) async {
    final notification = NotificationModel(
      type: 'belt',
      title: title,
      message: message,
      studentId: studentId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
    );
    await _repository.addNotification(notification);
  }

  /// إنشاء إشعار عام
  Future<void> createGeneralNotification({
    required String title,
    required String message,
    int? studentId,
    String? actionUrl,
  }) async {
    final notification = NotificationModel(
      type: 'general',
      title: title,
      message: message,
      studentId: studentId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      actionUrl: actionUrl,
    );
    await _repository.addNotification(notification);
  }

  /// الحصول على عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount() async {
    return await _repository.getUnreadCount();
  }
}
 */
