// lib/domain/repositories/i_attendance_repository.dart
import '../../data/models/attendance_record.dart';

abstract class IAttendanceRepository {
  // تحميل الحضور لفوج وتاريخ معين
  Future<List<AttendanceRecord>> getAttendanceForGroup({
    required int groupId,
    required DateTime date,
  });

  // تسجيل حضور طالب
  Future<void> markPresent({
    required int studentId,
    required int groupId,
    required DateTime date,
    bool viaQR = false,
  });

  // تسجيل غياب طالب
  Future<void> markAbsent({
    required int studentId,
    required int groupId,
    required DateTime date,
    String? excuseReason,
  });

  // التحقق من أن الطالب ينتمي إلى الفوج
  Future<bool> isStudentInGroup({required int studentId, required int groupId});

  // فك تشفير QR Code
  Future<String?> decodeQR(String qrData);

  // التحقق من الاتصال بالإنترنت
  Future<bool> checkConnectivity();

  // التحقق من وجود عمليات معلقة
  Future<bool> hasPendingOperations();
}
