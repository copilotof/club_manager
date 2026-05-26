// lib/presentation/bloc/attendance/attendance_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/attendance_record.dart';
import 'events/attendance_event.dart';
import 'states/attendance_state.dart';
import '../../../domain/repositories/i_attendance_repository.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final IAttendanceRepository _repository;

  AttendanceBloc(this._repository) : super(AttendanceInitial()) {
    on<LoadAttendanceEvent>(_onLoadAttendance);
    on<MarkPresentEvent>(_onMarkPresent);
    on<MarkAbsentEvent>(_onMarkAbsent);
    on<QRScannedEvent>(_onQRScanned);
  }

  Future<void> _onLoadAttendance(
    LoadAttendanceEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final records = await _repository.getAttendanceForGroup(
        groupId: event.groupId,
        date: event.date,
      );
      final isOnline = await _repository.checkConnectivity();
      final hasPending = await _repository.hasPendingOperations();

      emit(
        AttendanceLoaded(
          records: records.cast<AttendanceRecord>(),
          date: event.date,
          groupId: event.groupId,
          isOnline: isOnline,
          hasPendingSync: hasPending,
        ),
      );
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onMarkPresent(
    MarkPresentEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      await _repository.markPresent(
        studentId: event.studentId,
        groupId: event.groupId,
        date: event.date,
        viaQR: event.viaQR,
      );
      add(LoadAttendanceEvent(groupId: event.groupId, date: event.date));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onMarkAbsent(
    MarkAbsentEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      await _repository.markAbsent(
        studentId: event.studentId,
        groupId: event.groupId,
        date: event.date,
        excuseReason: event.excuseReason,
      );
      add(LoadAttendanceEvent(groupId: event.groupId, date: event.date));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onQRScanned(
    QRScannedEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      final studentIdStr = await _repository.decodeQR(event.qrData);
      if (studentIdStr == null) {
        emit(const AttendanceError('QR Code غير صالح'));
        return;
      }

      final studentId = int.tryParse(studentIdStr);
      if (studentId == null) {
        emit(const AttendanceError('QR Code غير صالح'));
        return;
      }

      final belongs = await _repository.isStudentInGroup(
        studentId: studentId,
        groupId: event.groupId,
      );

      if (!belongs) {
        emit(const AttendanceError('الطالب ليس من هذا الفوج'));
        return;
      }

      add(
        MarkPresentEvent(
          studentId: studentId,
          groupId: event.groupId,
          date: event.date,
          viaQR: true,
        ),
      );
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }
}
