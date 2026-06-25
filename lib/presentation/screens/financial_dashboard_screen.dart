// lib/presentation/screens/financial_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/student_model.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
import 'student_profile_screen.dart';

class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedTab = 0; // 0: المدانين, 1: المهدى إليهم

  List<StudentModel> _students = [];
  List<PaymentModel> _payments = [];
  bool _isLoading = true;

  // ✅ إضافة المتغيرات المطلوبة
  double _monthlyFee = 2000;
  double _insuranceFee = 1000;

  // قائمة المدانين (المتأخرات)
  List<Map<String, dynamic>> _debtors = [];

  // قائمة المهدى إليهم
  List<Map<String, dynamic>> _giftedStudents = [];

  late PaymentRepository _paymentRepo;
  late StudentRepository _studentRepo;

  List<int> _getAvailableYears() {
    final currentYear = DateTime.now().year;
    return [currentYear - 2, currentYear - 1, currentYear, currentYear + 1];
  }

  @override
  void initState() {
    super.initState();
    _paymentRepo = PaymentRepository(localDb: getIt());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _loadSettings();
    _loadData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyFee = prefs.getDouble('monthly_fee') ?? 2000;
      _insuranceFee = prefs.getDouble('insurance_fee') ?? 1000;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ إعادة تحميل الطلاب والدفعات
      _students = await _studentRepo.getAllStudents();
      _payments = await _paymentRepo.getAllPayments();

      // ✅ إعادة حساب المدانين والمهدى إليهم
      await _calculateDebtors();
      await _calculateGiftedStudents();
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // حساب المتأخرات (السنة الحالية من الشهر 1 إلى الشهر الحالي)
  Future<void> _calculateDebtors() async {
    final currentMonth = DateTime.now().month;
    List<Map<String, dynamic>> debtors = [];

    for (var student in _students) {
      double totalOutstanding = 0;

      // حساب الاشتراكات الشهرية غير المكتملة
      for (int month = 1; month <= currentMonth; month++) {
        final paid = await _paymentRepo.getTotalPaidForTarget(
          studentId: student.id!,
          paymentType: 'monthly',
          targetMonth: month,
          targetYear: _selectedYear,
        );
        if (paid < _monthlyFee) {
          totalOutstanding += (_monthlyFee - paid);
        }
      }

      // حساب التأمين غير المكتمل
      final insurancePaid = await _paymentRepo.getTotalPaidForTarget(
        studentId: student.id!,
        paymentType: 'insurance',
        targetYear: _selectedYear,
      );
      if (insurancePaid < _insuranceFee) {
        totalOutstanding += (_insuranceFee - insurancePaid);
      }

      if (totalOutstanding > 0) {
        debtors.add({'student': student, 'amount': totalOutstanding});
      }
    }

    // ترتيب من الأكثر إدانة إلى الأقل
    debtors.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    setState(() {
      _debtors = debtors;
    });
  }

  // حساب المهدى إليهم
  Future<void> _calculateGiftedStudents() async {
    Map<int, double> giftedMap = {};

    for (var payment in _payments) {
      if (payment.isGifted && payment.paymentDate.year == _selectedYear) {
        giftedMap[payment.studentId] =
            (giftedMap[payment.studentId] ?? 0) + payment.amount;
      }
    }

    List<Map<String, dynamic>> gifted = [];
    for (var student in _students) {
      if (giftedMap.containsKey(student.id)) {
        gifted.add({'student': student, 'amount': giftedMap[student.id]});
      }
    }

    // ترتيب من الأكثر إهداء إلى الأقل
    gifted.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    setState(() {
      _giftedStudents = gifted;
    });
  }

  // حساب إجمالي الإيرادات
  double get _totalIncome {
    return _payments
        .where((p) => p.paymentDate.year == _selectedYear && !p.isGifted)
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  // حساب إجمالي المهدى
  double get _totalGifted {
    return _payments
        .where((p) => p.paymentDate.year == _selectedYear && p.isGifted)
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  // حساب إجمالي المتأخرات
  Future<double> getTotalOutstanding() async {
    double total = 0;
    for (var student in _students) {
      for (int month = 1; month <= DateTime.now().month; month++) {
        final paid = await _paymentRepo.getTotalPaidForTarget(
          studentId: student.id!,
          paymentType: 'monthly',
          targetMonth: month,
          targetYear: _selectedYear,
        );
        if (paid < _monthlyFee) {
          total += (_monthlyFee - paid);
        }
      }
      final insurancePaid = await _paymentRepo.getTotalPaidForTarget(
        studentId: student.id!,
        paymentType: 'insurance',
        targetYear: _selectedYear,
      );
      if (insurancePaid < _insuranceFee) {
        total += (_insuranceFee - insurancePaid);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلومات المالية'),
        actions: [
          // اختيار السنة
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: _getAvailableYears().map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedYear = value ?? DateTime.now().year;
                  });
                  await _loadData();
                },
                dropdownColor: const Color(0xFFE53935),
              ),
            ),
          ),

          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // بطاقات الإحصائيات
          FutureBuilder<double>(
            future: getTotalOutstanding(),
            builder: (context, snapshot) {
              final outstanding = snapshot.data ?? 0;
              return Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'إجمالي الإيرادات',
                        '${_totalIncome.toStringAsFixed(0)} دج',
                        Icons.account_balance_wallet,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'المبالغ المتأخرة',
                        '${outstanding.toStringAsFixed(0)} دج',
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'المبالغ المهداة',
                        '${_totalGifted.toStringAsFixed(0)} دج',
                        Icons.card_giftcard,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // تبويبات المدانين والمهدى إليهم
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0
                                ? const Color(0xFFE53935)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'المدانين (المتأخرات)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0
                              ? const Color(0xFFE53935)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1
                                ? const Color(0xFFE53935)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'المهدى إليهم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1
                              ? const Color(0xFFE53935)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // محتوى التبويب
          Expanded(
            child: _selectedTab == 0 ? _buildDebtorsList() : _buildGiftedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtorsList() {
    if (_debtors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مدانين',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _debtors.length,
      itemBuilder: (context, index) {
        final item = _debtors[index];
        final student = item['student'] as StudentModel;
        final amount = item['amount'] as double;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            title: Text(
              student.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle:
                Text('متأخرات $_selectedYear: ${amount.toStringAsFixed(0)} دج'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
              onPressed: () => _showDebtorDialog(student),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDebtorDialog(StudentModel student) async {
    // ✅ حساب المبلغ الفعلي للطالب
    final debtAmount = await _calculateStudentDebt(student);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              student.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'مدان بمبلغ ${debtAmount.toStringAsFixed(0)} دج',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // ✅ فتح ملف الطالب في تبويب المدفوعات
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentProfileScreen(
                            studentId: student.id!,
                            initialTab: 1,
                          ),
                        ),
                      );
                      // ✅ بعد العودة، تحديث البيانات
                      if (result == true) {
                        await _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'فتح',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _calculateStudentDebt(StudentModel student) async {
    double totalDebt = 0;

    try {
      final paymentRepo = PaymentRepository(localDb: getIt());

      // ✅ حساب متأخرات الاشتراكات الشهرية
      for (int month = 1; month <= DateTime.now().month; month++) {
        final paid = await paymentRepo.getTotalPaidForTarget(
          studentId: student.id!,
          paymentType: 'monthly',
          targetMonth: month,
          targetYear: _selectedYear,
        );
        if (paid < _monthlyFee) {
          totalDebt += (_monthlyFee - paid);
        }
      }

      // ✅ حساب متأخرات التأمين
      final insurancePaid = await paymentRepo.getTotalPaidForTarget(
        studentId: student.id!,
        paymentType: 'insurance',
        targetYear: _selectedYear,
      );
      if (insurancePaid < _insuranceFee) {
        totalDebt += (_insuranceFee - insurancePaid);
      }
    } catch (e) {
      print('❌ خطأ في حساب المبلغ المدان: $e');
    }

    return totalDebt;
  }

// دوال مساعدة (مؤقتة)
  double _getMonthlyPaid(int studentId, int month, int year) {
    // ✅ يجب جلب البيانات من قاعدة البيانات
    // مؤقتاً: نستخدم 0 (يعني لم يدفع)
    return 0;
  }

  double _getInsurancePaid(int studentId, int year) {
    // ✅ يجب جلب البيانات من قاعدة البيانات
    // مؤقتاً: نستخدم 0 (يعني لم يدفع)
    return 0;
  }

  Widget _buildGiftedList() {
    if (_giftedStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 60, color: Colors.purple.shade300),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مهدى إليهم',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _giftedStudents.length,
      itemBuilder: (context, index) {
        final item = _giftedStudents[index];
        final student = item['student'] as StudentModel;
        final amount = item['amount'] as double;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: Colors.purple.shade700),
              ),
            ),
            title: Text(
              student.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('مبلغ مهدى في $_selectedYear'),
            trailing: Text(
              '${amount.toStringAsFixed(0)} دج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ),
        );
      },
    );
  }
}
