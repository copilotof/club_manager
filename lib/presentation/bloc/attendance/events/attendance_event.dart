// lib/presentation/bloc/attendance/events/attendance_event.dart
import 'package:equatable/equatable.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

// تحميل الحضور لفوج وتاريخ معين
class LoadAttendanceEvent extends AttendanceEvent {
  final int groupId;
  final DateTime date;
  const LoadAttendanceEvent({required this.groupId, required this.date});
  @override
  List<Object?> get props => [groupId, date];
}

// تسجيل حضور طالب (يدوي أو QR)
class MarkPresentEvent extends AttendanceEvent {
  final int studentId;
  final int groupId;
  final DateTime date;
  final bool viaQR;
  const MarkPresentEvent({
    required this.studentId,
    required this.groupId,
    required this.date,
    this.viaQR = false,
  });
  @override
  List<Object?> get props => [studentId, groupId, date, viaQR];
}

// تسجيل غياب طالب (مع سبب اختياري)
class MarkAbsentEvent extends AttendanceEvent {
  final int studentId;
  final int groupId;
  final DateTime date;
  final String? excuseReason;
  const MarkAbsentEvent({
    required this.studentId,
    required this.groupId,
    required this.date,
    this.excuseReason,
  });
  @override
  List<Object?> get props => [studentId, groupId, date, excuseReason];
}

// مسح QR Code
class QRScannedEvent extends AttendanceEvent {
  final String qrData;
  final int groupId;
  final DateTime date;
  const QRScannedEvent({
    required this.qrData,
    required this.groupId,
    required this.date,
  });
  @override
  List<Object?> get props => [qrData, groupId, date];
}
