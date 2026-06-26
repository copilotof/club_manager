// lib/presentation/bloc/notification/notification_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'events/notification_event.dart';
import 'states/notification_state.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  NotificationBloc(this._repository) : super(NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<LoadUnreadNotificationsEvent>(_onLoadUnreadNotifications);
    on<MarkAsReadEvent>(_onMarkAsRead);
    on<MarkAllAsReadEvent>(_onMarkAllAsRead);
    on<DeleteNotificationEvent>(_onDeleteNotification);
    on<DeleteAllReadEvent>(_onDeleteAllRead);
    on<GetUnreadCountEvent>(_onGetUnreadCount);
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final notifications = await _repository.getAllNotifications();
      emit(NotificationsLoaded(notifications));
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onLoadUnreadNotifications(
    LoadUnreadNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final notifications = await _repository.getUnreadNotifications();
      emit(NotificationsLoaded(notifications));
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _repository.markAsRead(event.notificationId);
      emit(const NotificationOperationSuccess('تم وضع علامة مقروء'));
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _repository.markAllAsRead();
      emit(const NotificationOperationSuccess('تم وضع علامة مقروء على الكل'));
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _repository.deleteNotification(event.notificationId);
      emit(const NotificationOperationSuccess('تم حذف الإشعار'));
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onDeleteAllRead(
    DeleteAllReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _repository.deleteAllRead();
      emit(const NotificationOperationSuccess('تم حذف الإشعارات المقروءة'));
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onGetUnreadCount(
    GetUnreadCountEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final count = await _repository.getUnreadCount();
      emit(NotificationCountLoaded(count));
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }
}
