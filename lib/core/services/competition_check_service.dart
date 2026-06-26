// lib/core/services/competition_check_service.dart
import '../../data/models/competition_model.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/notification_model.dart';
import '../../injection/dependency_injection.dart';

/// خدمة فحص البطولات القادمة
class CompetitionCheckService {
  late CompetitionRepository _competitionRepo;
  late NotificationRepository _notificationRepo;

  CompetitionCheckService() {
    _competitionRepo = CompetitionRepository(localDb: getIt());
    _notificationRepo = NotificationRepository(localDb: getIt());
  }

  /// فحص البطولات القادمة
  Future<void> checkUpcomingCompetitions() async {
    try {
      final competitions = await _competitionRepo.getUpcomingCompetitions();

      for (var competition in competitions) {
        // حساب الأيام المتبقية
        final daysLeft =
            competition.startDate.difference(DateTime.now()).inDays;

        // إذا كانت البطولة بعد 7 أيام ولم نرسل إشعاراً عنها
        if (daysLeft <= 7 && daysLeft >= 0) {
          await _createCompetitionNotification(competition, daysLeft);
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص البطولات القادمة: $e');
    }
  }

  /// إنشاء إشعار بطولة قادمة
  Future<void> _createCompetitionNotification(
    CompetitionModel competition,
    int daysLeft,
  ) async {
    // التحقق من وجود إشعار سابق لهذه البطولة
    final existingNotifications = await _notificationRepo.getAllNotifications();
    final recentNotification = existingNotifications.any((n) =>
        n.type == 'competition' &&
        n.relatedId == competition.id &&
        n.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1))));

    if (recentNotification) return;

    final notification = NotificationModel(
      type: 'competition',
      title: '🏆 بطولة قادمة: ${competition.name}',
      message: 'تبدأ البطولة بعد $daysLeft يوماً في ${competition.location}',
      relatedId: competition.id,
      createdAt: DateTime.now(),
      targetAudience: 'admin',
      priority: 1,
      actionUrl: '/competition/${competition.id}',
    );

    await _notificationRepo.addNotification(notification);
    print('✅ تم إنشاء إشعار للبطولة ${competition.name}');
  }
}
