// lib/presentation/bloc/attendance/states/attendance_state.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/attendance_record.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final List<AttendanceRecord> records;
  final DateTime date;
  final int groupId;
  final bool isOnline;
  final bool hasPendingSync;
  const AttendanceLoaded({
    required this.records,
    required this.date,
    required this.groupId,
    this.isOnline = true,
    this.hasPendingSync = false,
  });
  @override
  List<Object?> get props => [records, date, groupId, isOnline, hasPendingSync];
}

class AttendanceMarked extends AttendanceState {}

class AttendanceSyncing extends AttendanceState {}

class AttendanceSynced extends AttendanceState {}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError(this.message);
  @override
  List<Object?> get props => [message];
}
