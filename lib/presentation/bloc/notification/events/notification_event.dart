// lib/presentation/bloc/notification/events/notification_event.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/notification_model.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

/// تحميل جميع الإشعارات
class LoadNotificationsEvent extends NotificationEvent {}

/// تحميل الإشعارات غير المقروءة
class LoadUnreadNotificationsEvent extends NotificationEvent {}

/// وضع علامة مقروء على إشعار
class MarkAsReadEvent extends NotificationEvent {
  final int notificationId;
  const MarkAsReadEvent(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

/// وضع علامة مقروء على جميع الإشعارات
class MarkAllAsReadEvent extends NotificationEvent {}

/// حذف إشعار
class DeleteNotificationEvent extends NotificationEvent {
  final int notificationId;
  const DeleteNotificationEvent(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

/// حذف جميع الإشعارات المقروءة
class DeleteAllReadEvent extends NotificationEvent {}

/// الحصول على عدد الإشعارات غير المقروءة
class GetUnreadCountEvent extends NotificationEvent {}
