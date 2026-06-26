// lib/core/services/attendance_check_service.dart
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/notification_model.dart';
import '../../injection/dependency_injection.dart';

/// خدمة فحص الغياب المتكرر
class AttendanceCheckService {
  late AttendanceRepository _attendanceRepo;
  late StudentRepository _studentRepo;
  late NotificationRepository _notificationRepo;

  AttendanceCheckService() {
    _attendanceRepo = AttendanceRepository(
      localDb: getIt(),
      remoteApi: getIt(),
      connectivity: getIt(),
    );
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _notificationRepo = NotificationRepository(localDb: getIt());
  }

  /// فحص الغياب المتكرر لجميع الطلاب
  Future<void> checkRecurrentAbsences() async {
    try {
      // جلب جميع الطلاب النشطين
      final students = await _studentRepo.getAllStudents();

      for (var student in students) {
        await _checkStudentAbsences(student.id!);
      }
    } catch (e) {
      print('❌ خطأ في فحص الغياب المتكرر: $e');
    }
  }

  /// فحص غيابات طالب معين
  Future<void> _checkStudentAbsences(int studentId) async {
    try {
      // جلب آخر 5 حصص للطالب
      final records = await _attendanceRepo.getStudentAttendance(
        studentId: studentId,
        limit: 5,
      );

      // حساب عدد الغيابات المتتالية
      int consecutiveAbsences = 0;
      for (var record in records) {
        if (!record.isPresent) {
          consecutiveAbsences++;
        } else {
          break; // توقف عند أول حضور
        }
      }

      // إذا كان هناك 3 غيابات متتالية أو أكثر
      if (consecutiveAbsences >= 3) {
        await _createAbsenceNotification(studentId, consecutiveAbsences);
      }
    } catch (e) {
      print('❌ خطأ في فحص غيابات الطالب $studentId: $e');
    }
  }

  /// إنشاء إشعار غياب متكرر
  Future<void> _createAbsenceNotification(int studentId, int count) async {
    // جلب اسم الطالب
    final student = await _studentRepo.getStudentById(studentId);
    if (student == null) return;

    // التحقق من وجود إشعار سابق لهذا الطالب خلال اليومين الماضيين
    final existingNotifications =
        await _notificationRepo.getNotificationsByStudent(studentId);
    final recentNotification = existingNotifications.any((n) =>
        n.type == 'attendance' &&
        n.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 2))));

    if (recentNotification) return; // لا نكرر الإشعار

    final notification = NotificationModel(
      type: 'attendance',
      title: '⚠️ غياب متكرر للطالب ${student.fullName}',
      message:
          'تغيب الطالب ${student.fullName} عن $count حصص تدريبية متتالية، يرجى متابعته',
      studentId: studentId,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
    );

    await _notificationRepo.addNotification(notification);
    print('✅ تم إنشاء إشعار غياب متكرر للطالب ${student.fullName}');
  }
}
