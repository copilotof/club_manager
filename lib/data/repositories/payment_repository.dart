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

    // ✅ حذف إشعارات الدفع المتأخر لهذا الطالب
    await db.delete(
      'notifications',
      where: 'type = ? AND student_id = ? AND is_read = 0',
      whereArgs: ['payment', payment.studentId],
    );

    print('✅ تم حذف إشعارات الدفع للطالب ${payment.studentId}');

    print(
      '💰 PaymentRepository: تم إدراج دفعة جديدة - id=$id, student_id=${payment.studentId}, amount=${payment.amount}',
    );
  }

  @override
  Future<void> deletePayment(int paymentId) async {
    final db = await _db;
    await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
    print('🗑️ تم حذف الدفعة رقم $paymentId');
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

  // الحصول على مجموع دفعات معينة (للتأمين أو الشهر)
  @override
  Future<double> getTotalPaidForTarget({
    required int studentId,
    required String paymentType,
    int? targetMonth,
    int? targetYear,
  }) async {
    final db = await _db;

    // جلب تاريخ تسجيل الطالب
    final studentResult = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
    );

    if (studentResult.isEmpty) return 0;
    final enrollmentDate =
        DateTime.parse(studentResult.first['enrollment_date'] as String);
    final enrollmentMonth = enrollmentDate.month;
    final enrollmentYear = enrollmentDate.year;

    // إذا كان الشهر المستهدف قبل تاريخ التسجيل، لا يتم احتسابه
    if (targetYear != null && targetMonth != null) {
      if (targetYear < enrollmentYear ||
          (targetYear == enrollmentYear && targetMonth < enrollmentMonth)) {
        return 0;
      }
    }

    // ✅ بناء الاستعلام بشكل صحيح
    String query =
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ? AND payment_type = ?';
    List<Object?> args = [studentId, paymentType];

    if (targetMonth != null) {
      query += ' AND target_month = ?';
      args.add(targetMonth);
    }

    if (targetYear != null) {
      query += ' AND target_year = ?';
      args.add(targetYear);
    }

    try {
      final result = await db.rawQuery(query, args);
      return (result.first['total'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      print('❌ خطأ في الاستعلام: $e');
      // استعلام بديل إذا فشل
      final fallbackResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE student_id = ? AND payment_type = ? AND year = ?',
        [studentId, paymentType, targetYear ?? DateTime.now().year],
      );
      return (fallbackResult.first['total'] as num?)?.toDouble() ?? 0;
    }
  }

  // تحديث حالة الدفعة (مكتملة أم لا)
  Future<void> updatePaymentStatus(
    int paymentId,
    bool isFullyPaid,
    double remaining,
  ) async {
    final db = await _db;
    await db.update(
      'payments',
      {'is_fully_paid': isFullyPaid ? 1 : 0, 'remaining_amount': remaining},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
  }
}
