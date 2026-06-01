// lib/data/repositories/payment_repository.dart
import 'package:sqflite/sqflite.dart';
import '../../injection/dependency_injection.dart';
import '../models/payment_model.dart';
import '../../domain/repositories/i_payment_repository.dart';
import '../datasources/local/app_database.dart';

class PaymentRepository implements IPaymentRepository {
  final AppDatabase _localDb;

  PaymentRepository({required AppDatabase localDb}) : _localDb = localDb;

  Future<Database> get _db async => await _localDb.database;

  @override
  Future<List<PaymentModel>> getAllPayments() async {
    final db = await _db;
    final result = await db.query('payments', orderBy: 'payment_date DESC');
    return result.map((map) => PaymentModel.fromMap(map)).toList();
  }

  @override
  Future<List<PaymentModel>> getStudentPayments(int studentId) async {
    final db = await _db;
    print('🔍 PaymentRepository: البحث عن دفعات للطالب $studentId');

    final result = await db.query(
      'payments',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'payment_date DESC',
    );

    print('🔍 PaymentRepository: وجدت ${result.length} دفعة');

    // طباعة تفاصيل الدفعات للتصحيح
    for (var row in result) {
      print(
        '   - دفعة: amount=${row['amount']}, type=${row['payment_type']}, date=${row['payment_date']}',
      );
    }

    return result.map((map) => PaymentModel.fromMap(map)).toList();
  }

  // مؤقتاً: اطبع محتويات قاعدة البيانات
  Future<void> _debugPrintPayments() async {
    final db = await getIt<AppDatabase>().database;
    final result = await db.query('payments');
    print('📊 جميع الدفعات في قاعدة البيانات: ${result.length}');
    for (var row in result) {
      print(
        '   - الدفعة: student_id=${row['student_id']}, amount=${row['amount']}, type=${row['payment_type']}',
      );
    }
  }

  @override
  Future<void> addPayment(PaymentModel payment) async {
    final db = await _db;
    final id = await db.insert('payments', payment.toMap());
    print(
      '💰 PaymentRepository: تم إدراج دفعة جديدة - id=$id, student_id=${payment.studentId}, amount=${payment.amount}',
    );
  }

  @override
  Future<void> deletePayment(int paymentId) async {
    final db = await _db;
    await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  @override
  Future<double> getTotalIncome() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments WHERE is_gifted = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<double> getTotalOutstanding() async {
    // حساب المتأخرات: (عدد الأشهر × 2000) - المدفوع
    // هذا مؤقت، سيتم تطويره لاحقاً
    final db = await _db;
    final students = await db.query('students', where: 'is_active = 1');
    final payments = await db.query('payments');

    double totalOutstanding = 0;
    for (var student in students) {
      final studentId = student['id'];
      final studentPayments = payments.where(
        (p) => p['student_id'] == studentId,
      );
      final paid = studentPayments.fold<double>(
        0,
        (sum, p) => sum + (p['amount'] as num).toDouble(),
      );

      // حساب المستحق (مؤقت: 2000 دينار شهرياً)
      final enrollmentDate = DateTime.parse(
        student['enrollment_date'] as String,
      );
      final monthsSince =
          DateTime.now().difference(enrollmentDate).inDays ~/ 30;
      final expected = monthsSince * 2000.0;

      if (expected > paid) {
        totalOutstanding += (expected - paid);
      }
    }
    return totalOutstanding;
  }
}
