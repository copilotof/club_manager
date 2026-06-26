// lib/presentation/bloc/notification/states/notification_state.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/notification_model.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationsLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  const NotificationsLoaded(this.notifications);
  @override
  List<Object?> get props => [notifications];
}

class NotificationCountLoaded extends NotificationState {
  final int count;
  const NotificationCountLoaded(this.count);
  @override
  List<Object?> get props => [count];
}

class NotificationOperationSuccess extends NotificationState {
  final String message;
  const NotificationOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
  @override
  List<Object?> get props => [message];
}
