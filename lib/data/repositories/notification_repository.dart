// lib/data/repositories/notification_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/notification_model.dart';
import '../datasources/local/app_database.dart';

/// مستودع الإشعارات - مسؤول عن عمليات CRUD للإشعارات
class NotificationRepository {
  final AppDatabase _localDb;

  NotificationRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  /// جلب جميع الإشعارات (مرتبة من الأحدث إلى الأقدم)
  Future<List<NotificationModel>> getAllNotifications() async {
    final db = await _db;
    final result = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => NotificationModel.fromMap(map)).toList();
  }

  /// جلب الإشعارات غير المقروءة فقط
  Future<List<NotificationModel>> getUnreadNotifications() async {
    final db = await _db;
    final result = await db.query(
      'notifications',
      where: 'is_read = 0',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => NotificationModel.fromMap(map)).toList();
  }

  /// جلب الإشعارات حسب النوع
  Future<List<NotificationModel>> getNotificationsByType(String type) async {
    final db = await _db;
    final result = await db.query(
      'notifications',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => NotificationModel.fromMap(map)).toList();
  }

  /// جلب إشعارات طالب معين
  Future<List<NotificationModel>> getNotificationsByStudent(
      int studentId) async {
    final db = await _db;
    final result = await db.query(
      'notifications',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => NotificationModel.fromMap(map)).toList();
  }

  /// إضافة إشعار جديد
  Future<int> addNotification(NotificationModel notification) async {
    final db = await _db;
    return await db.insert('notifications', notification.toMap());
  }

  /// تحديث إشعار (تغيير حالة القراءة)
  Future<int> updateNotification(NotificationModel notification) async {
    final db = await _db;
    return await db.update(
      'notifications',
      notification.toMap(),
      where: 'id = ?',
      whereArgs: [notification.id],
    );
  }

  /// وضع علامة "مقروء" على إشعار
  Future<int> markAsRead(int id) async {
    final db = await _db;
    return await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// وضع علامة "مقروء" على جميع الإشعارات
  Future<int> markAllAsRead() async {
    final db = await _db;
    return await db.update(
      'notifications',
      {'is_read': 1},
    );
  }

  /// حذف إشعار
  Future<int> deleteNotification(int id) async {
    final db = await _db;
    return await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  /// حذف جميع الإشعارات المقروءة
  Future<int> deleteAllRead() async {
    final db = await _db;
    return await db.delete('notifications', where: 'is_read = 1');
  }

  /// الحصول على عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount() async {
    final db = await _db;
    final result = await db.query(
      'notifications',
      where: 'is_read = 0',
    );
    return result.length;
  }
}
