// lib/presentation/screens/student_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/models/belt_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/belt_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../bloc/student/student_bloc.dart';
import '../bloc/student/events/student_event.dart';
import '../bloc/student/states/student_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
import 'add_belt_screen.dart';
import 'add_edit_student_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'student_payments_screen.dart';

import 'add_payment_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final int studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with SingleTickerProviderStateMixin {
  late StudentBloc _studentBloc;
  late TabController _tabController;
  late Future<List<PaymentModel>> _paymentsFuture;
  bool _paymentsRefresh = false;

  StudentModel? _student;
  bool _isLoading = true;
  bool _showOnlyExtra = false; // ✅ متغير جديد لتصفية المستحقات الإضافية

  int _selectedYear = DateTime.now().year;
  bool _showOnlyUnpaid = false;

  double _monthlyFee = 2000;
  double _insuranceFee = 1000;

  List<BeltModel> _studentBelts = [];

  @override
  void initState() {
    super.initState();
    _studentBloc = StudentBloc(getIt());
    _tabController = TabController(length: 7, vsync: this);
    _studentBloc.add(LoadStudentsEvent());
    _loadFees(); // ✅ تحميل القيم من الإعدادات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDatabaseStructure();
    });
    _loadStudentBelts();
  }

  void _refreshPayments() {
    setState(() {
      _paymentsRefresh = !_paymentsRefresh;
      _paymentsFuture = _getStudentPayments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // ✅ لا نغلق _studentBloc لأنه قد يكون مستخدماً في مكان آخر
    super.dispose();
  }

  void _editStudent() async {
    if (_student == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditStudentScreen(student: _student),
      ),
    );
    if (result == true && mounted) {
      // ✅ إعادة تحميل البيانات بعد التعديل
      _studentBloc.add(LoadStudentsEvent());
    }
  }

  void _showQRCode() {
    if (_student == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'بطاقة الطالب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: _student!.id.toString(),
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _student!.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الرقم التعريفي: ${_student!.id}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                ),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // أضف هذه الدالة في _StudentProfileScreenState
  Future<void> _checkDatabaseStructure() async {
    final db = await getIt<AppDatabase>().database;

    // التحقق من وجود جدول payments
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='payments'",
    );
    print('📊 هل جدول payments موجود؟ ${tables.isNotEmpty}');

    if (tables.isNotEmpty) {
      // عرض هيكل الجدول
      final structure = await db.rawQuery("PRAGMA table_info(payments)");
      print('📊 هيكل جدول payments:');
      for (var col in structure) {
        print('   - ${col['name']}: ${col['type']}');
      }

      // عرض جميع الدفعات في قاعدة البيانات
      final allPayments = await db.query('payments');
      print('📊 إجمالي الدفعات في قاعدة البيانات: ${allPayments.length}');
      for (var p in allPayments) {
        print(
          '   - الدفعة: id=${p['id']}, student_id=${p['student_id']}, amount=${p['amount']}, type=${p['payment_type']}',
        );
      }
    }
  }

  Future<void> _loadFees() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyFee = prefs.getDouble('monthly_fee') ?? 2000;
      _insuranceFee = prefs.getDouble('insurance_fee') ?? 1000;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return BlocProvider.value(
      value: _studentBloc,
      child: Scaffold(
        appBar: AppBar(
          title: _student != null
              ? Text(_student!.fullName)
              : const Text('ملف الطالب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _showQRCode,
              tooltip: 'عرض QR Code',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editStudent,
              tooltip: 'تعديل',
            ),
          ],

          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'معلومات شخصية', icon: Icon(Icons.person)),
              Tab(text: 'المدفوعات', icon: Icon(Icons.payments)),
              Tab(text: 'معلومات دراسية', icon: Icon(Icons.school)),
              Tab(text: 'معلومات صحية', icon: Icon(Icons.health_and_safety)),
              Tab(
                text: '🥋 الأحزمة',
                icon: Icon(Icons.sports_martial_arts),
              ), // ✅ جديد
              Tab(text: 'السجل الرياضي', icon: Icon(Icons.emoji_events)),
              Tab(text: 'إحصائيات', icon: Icon(Icons.bar_chart)),
            ],
          ),
        ),
        body: BlocListener<StudentBloc, StudentState>(
          listener: (context, state) {
            if (state is StudentsLoaded && mounted) {
              // ✅ تحديث البيانات عند تغيرها
              final updatedStudent = state.students.firstWhere(
                (s) => s.id == widget.studentId,
                orElse: () => _student!,
              );
              setState(() {
                _student = updatedStudent;
                _isLoading = false;
              });
            }
            if (state is StudentError && mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: BlocBuilder<StudentBloc, StudentState>(
            builder: (context, state) {
              if (_isLoading && state is! StudentsLoaded) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_student == null && state is StudentsLoaded) {
                final found = state.students.firstWhere(
                  (s) => s.id == widget.studentId,
                  orElse: () => throw Exception('الطالب غير موجود'),
                );
                _student = found;
                _isLoading = false;
              }

              if (_student == null) {
                return const Center(child: Text('الطالب غير موجود'));
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalInfoTab(isMobile),
                  _buildPaymentsTab(isMobile),
                  _buildAcademicInfoTab(isMobile),
                  _buildHealthInfoTab(isMobile),
                  _buildBeltsTab(isMobile), // ✅ الأحزمة
                  _buildSportsRecordTab(isMobile), // البطولات
                  _buildStatisticsTab(isMobile),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // باقي الدوال (_buildPersonalInfoTab, _buildAcademicInfoTab, إلخ)
  // تبقى كما هي دون تغيير

  Widget _buildPersonalInfoTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'معلومات أساسية',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow('الاسم الكامل', _student!.fullName),
              _buildDivider(),
              _buildInfoRow(
                'الجنس',
                _student!.gender == 'ذكر' ? '♂ ذكر' : '♀ أنثى',
              ),
              _buildDivider(),
              _buildInfoRow('تاريخ الميلاد', _formatDate(_student!.birthDate)),
              _buildDivider(),
              _buildInfoRow('العمر', '${_student!.age} سنة'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'معلومات الاتصال',
            icon: Icons.contact_phone,
            children: [
              _buildInfoRow(
                'رقم ولي الأمر',
                _student!.parentPhone ?? 'غير مسجل',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'معلومات التسجيل',
            icon: Icons.calendar_today,
            children: [
              _buildInfoRow(
                'تاريخ التسجيل',
                _formatDate(_student!.enrollmentDate),
              ),
              _buildDivider(),
              _buildInfoRow('رقم التسجيل', '#${_student!.id}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(bool isMobile) {
    return Column(
      children: [
        // شريط التصفية العلوي
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صف السنة وزر الإضافة
              Row(
                children: [
                  // اختيار السنة
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('جميع السنوات'),
                            ),
                            DropdownMenuItem(value: 2026, child: Text('2026')),
                            DropdownMenuItem(value: 2025, child: Text('2025')),
                            DropdownMenuItem(value: 2024, child: Text('2024')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value ?? DateTime.now().year;
                              _paymentsRefresh = !_paymentsRefresh;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ زر "دفعة جديدة" - تم إصلاحه
                  SizedBox(
                    width: 50,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              /*
              // فلتر المبالغ غير المسددة
              FilterChip(
                label: const Text('غير مكتملة'),
                selected: _showOnlyUnpaid,
                onSelected: (value) {
                  setState(() {
                    _showOnlyUnpaid = value;
                    _paymentsRefresh = !_paymentsRefresh;
                  });
                },
                selectedColor: const Color(0xFFE53935).withOpacity(0.2),
              ),
              */
              // صف الأزرار
              Wrap(
                spacing: 8,
                children: [
                  // فلتر المبالغ غير المسددة
                  FilterChip(
                    label: const Text('غير مكتملة'),
                    selected: _showOnlyUnpaid,
                    onSelected: (value) {
                      setState(() {
                        _showOnlyUnpaid = value;
                        if (value) _showOnlyExtra = false; // إلغاء الفلتر الآخر
                        _paymentsRefresh = !_paymentsRefresh;
                      });
                    },
                    selectedColor: const Color(0xFFE53935).withOpacity(0.2),
                  ),
                  // ✅ فلتر المستحقات الإضافية
                  FilterChip(
                    label: const Text('مستحقات إضافية'),
                    selected: _showOnlyExtra,
                    onSelected: (value) {
                      setState(() {
                        _showOnlyExtra = value;
                        if (value)
                          _showOnlyUnpaid = false; // إلغاء الفلتر الآخر
                        _paymentsRefresh = !_paymentsRefresh;
                      });
                    },
                    selectedColor: Colors.orange.withOpacity(0.2),
                    avatar: const Icon(Icons.shopping_bag, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        // قائمة الدفعات
        Expanded(
          child: FutureBuilder<List<PaymentModel>>(
            key: ValueKey(_paymentsRefresh),
            future: _getStudentPaymentsFiltered(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _paymentsRefresh = !_paymentsRefresh;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }

              final payments = snapshot.data ?? [];

              if (payments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد مدفوعات',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: _addPayment,
                          icon: const Icon(Icons.add),
                          label: const Text('تسجيل دفعة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final totalPaid = payments.fold<double>(
                0,
                (sum, p) => sum + p.amount,
              );

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // بطاقة الإجمالي
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'إجمالي المدفوعات',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalPaid.toStringAsFixed(0)} دج',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${payments.length} دفعة',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...payments.map((p) => _buildPaymentCard(p)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBeltsTab(bool isMobile) {
    return Column(
      children: [
        // زر إضافة حزام جديد
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddBeltScreen(
                    studentId: widget.studentId,
                    onBeltAdded: () {
                      _loadStudentBelts();
                    },
                  ),
                ),
              );
              if (result == true) {
                _loadStudentBelts();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('تسجيل ترقية جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
          ),
        ),

        // قائمة الأحزمة
        Expanded(
          child: _studentBelts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_martial_arts,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد ترقيات مسجلة',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _studentBelts.length,
                  itemBuilder: (context, index) {
                    final belt = _studentBelts[index];
                    return _buildBeltCard(belt);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBeltCard(BeltModel belt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: belt.getColor(),
            shape: BoxShape.circle,
            border: belt.beltColor == 'أبيض'
                ? Border.all(color: Colors.grey.shade300)
                : null,
          ),
          child: Center(
            child: Icon(Icons.circle, color: belt.getColor(), size: 30),
          ),
        ),
        title: Text(
          belt.beltColor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: belt.getTextColor(),
          ),
        ),
        subtitle: Text(
          'تاريخ الترقية: ${belt.dateAchieved.year}/${belt.dateAchieved.month}/${belt.dateAchieved.day}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteBelt(belt),
        ),
      ),
    );
  }

  void _deleteBelt(BeltModel belt) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ترقية الحزام "${belt.beltColor}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = BeltRepository(localDb: getIt());
      await repo.deleteBelt(belt.id!);
      await _loadStudentBelts();
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'تم حذف الترقية');
    }
  }

  Future<List<PaymentModel>> _getStudentPaymentsFiltered() async {
    final payments = await _getStudentPayments();

    var filtered = payments;

    // تصفية حسب السنة
    if (_selectedYear != 0) {
      filtered = filtered
          .where((p) => p.paymentDate.year == _selectedYear)
          .toList();
    }

    // ✅ فلتر المستحقات الإضافية
    if (_showOnlyExtra) {
      filtered = filtered.where((p) => p.paymentType == 'extra').toList();
      return filtered;
    }

    // ✅ فلتر المبالغ غير المكتملة
    if (_showOnlyUnpaid) {
      // تجميع الدفعات حسب الهدف (شهرية أو تأمين)
      Map<String, double> totals = {};
      Map<String, String> types = {};

      for (var p in filtered) {
        String key;
        if (p.paymentType == 'monthly') {
          // مفتاح للاشتراك الشهري: الشهر + السنة
          key = 'monthly_${p.targetYear ?? p.year}_${p.targetMonth ?? p.month}';
          types[key] = 'monthly';
        } else if (p.paymentType == 'insurance') {
          // مفتاح للتأمين: السنة فقط
          key = 'insurance_${p.targetYear ?? p.year}';
          types[key] = 'insurance';
        } else {
          continue; // تجاهل المستحقات الإضافية
        }
        totals[key] = (totals[key] ?? 0) + p.amount;
      }

      // تحديد المفاتيح غير المكتملة
      Set<String> incompleteKeys = {};
      for (var entry in totals.entries) {
        final key = entry.key;
        final total = entry.value;
        final requiredAmount = types[key] == 'monthly'
            ? _monthlyFee
            : _insuranceFee;

        if (total < requiredAmount) {
          incompleteKeys.add(key);
          print('📊 غير مكتمل: $key = $total / $requiredAmount');
        } else {
          print('✅ مكتمل: $key = $total / $requiredAmount');
        }
      }

      // تصفية الدفعات التي تظهر
      filtered = filtered.where((p) {
        // استبعاد المستحقات الإضافية من التصفية
        if (p.paymentType == 'extra') return false;

        String key;
        if (p.paymentType == 'monthly') {
          key = 'monthly_${p.targetYear ?? p.year}_${p.targetMonth ?? p.month}';
        } else if (p.paymentType == 'insurance') {
          key = 'insurance_${p.targetYear ?? p.year}';
        } else {
          return false;
        }

        return incompleteKeys.contains(key);
      }).toList();
    }

    return filtered;
  }

  bool _isPaymentIncomplete(PaymentModel p) {
    // اعتماداً على البيانات الموجودة في الدفعة نفسها
    if (p.paymentType == 'monthly') {
      return p.isPartial == true || p.isFullyPaid == false;
    }

    if (p.paymentType == 'insurance') {
      return p.isPartial == true || p.isFullyPaid == false;
    }

    if (p.paymentType == 'extra') {
      return false; // المستحقات الإضافية لا تظهر
    }

    return false;
  }

  void _deletePayment(int paymentId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الدفعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final paymentRepo = PaymentRepository(localDb: getIt());
              await paymentRepo.deletePayment(paymentId);
              setState(() {
                _paymentsRefresh = !_paymentsRefresh;
              });
              if (!mounted) return;
              Navigator.pop(context);
              CustomSnackbar.showSuccess(context, 'تم حذف الدفعة بنجاح');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfoTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'المعدلات الدراسية',
            icon: Icons.grade,
            children: [
              _buildInfoRow(
                'معدل الفصل الأول',
                _student!.semester1Grade?.toString() ?? 'لم يسجل بعد',
              ),
              _buildDivider(),
              _buildInfoRow(
                'معدل الفصل الثاني',
                _student!.semester2Grade?.toString() ?? 'لم يسجل بعد',
              ),
              _buildDivider(),
              _buildInfoRow(
                'معدل الفصل الثالث',
                _student!.semester3Grade?.toString() ?? 'لم يسجل بعد',
              ),
            ],
          ),
          if (_student!.academicNotes != null &&
              _student!.academicNotes!.isNotEmpty)
            const SizedBox(height: 16),
          if (_student!.academicNotes != null &&
              _student!.academicNotes!.isNotEmpty)
            _buildInfoCard(
              title: 'ملاحظات المدرب',
              icon: Icons.note,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _student!.academicNotes!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHealthInfoTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'الحالة الصحية',
            icon: Icons.health_and_safety,
            children: [
              _buildInfoRow(
                'مرض مزمن',
                _student!.hasChronicDisease ? 'نعم' : 'لا',
              ),
              if (_student!.hasChronicDisease) ...[
                _buildDivider(),
                _buildInfoRow('نوع المرض', _student!.diseaseName ?? 'غير محدد'),
                if (_student!.medications != null) ...[
                  _buildDivider(),
                  _buildInfoRow('الأدوية', _student!.medications!),
                ],
                if (_student!.medicalInstructions != null) ...[
                  _buildDivider(),
                  _buildInfoRow('تعليمات خاصة', _student!.medicalInstructions!),
                ],
              ],
            ],
          ),
          if (_student!.doctorName != null || _student!.emergencyPhone != null)
            const SizedBox(height: 16),
          if (_student!.doctorName != null || _student!.emergencyPhone != null)
            _buildInfoCard(
              title: 'معلومات الطوارئ',
              icon: Icons.emergency,
              children: [
                if (_student!.doctorName != null)
                  _buildInfoRow('الطبيب المعالج', _student!.doctorName!),
                if (_student!.doctorName != null &&
                    _student!.emergencyPhone != null)
                  _buildDivider(),
                if (_student!.emergencyPhone != null)
                  _buildInfoRow('رقم الطوارئ', _student!.emergencyPhone!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSportsRecordTab(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_martial_arts, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'سجل الأحزمة والبطولات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم إضافة هذه الميزة قريباً',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFFE53935)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(bool isMobile) {
    final attendancePercentage = _getAttendancePercentage();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نسبة الحضور الإجمالية
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'نسبة الحضور الكلية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: CircularProgressIndicator(
                          value: attendancePercentage / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE53935),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${attendancePercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          const Text('حضور', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // الرسم البياني للحضور الأسبوعي
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الحضور الأسبوعي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 7,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const weeks = [
                                  'أسبوع 1',
                                  'أسبوع 2',
                                  'أسبوع 3',
                                  'أسبوع 4',
                                ];
                                if (value.toInt() >= 0 &&
                                    value.toInt() < weeks.length) {
                                  return Text(
                                    weeks[value.toInt()],
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        barGroups: _getAttendanceStats().entries.map((entry) {
                          final index = _getAttendanceStats().keys
                              .toList()
                              .indexOf(entry.key);
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                color: const Color(0xFFE53935),
                                width: 30,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // مؤشر التزام الدفع
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الالتزام المالي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'المدفوع',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '85%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'المتبقي',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '15%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.85,
                    backgroundColor: Colors.grey[200],
                    color: Colors.green,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ دالة جلب المدفوعات المحسّنة
  Future<List<PaymentModel>> _getStudentPayments() async {
    try {
      final db = await getIt<AppDatabase>().database;

      // استعلام مباشر من قاعدة البيانات
      final result = await db.query(
        'payments',
        where: 'student_id = ?',
        whereArgs: [widget.studentId],
        orderBy: 'payment_date DESC',
      );

      print(
        '📊 استعلام مباشر: وجدت ${result.length} دفعة للطالب ${widget.studentId}',
      );

      if (result.isNotEmpty) {
        for (var row in result) {
          print(
            '   - الدفعة: ${row['amount']} دج, النوع: ${row['payment_type']}, التاريخ: ${row['payment_date']}',
          );
        }
      }

      return result.map((map) => PaymentModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ خطأ في جلب المدفوعات: $e');
      return [];
    }
  }

  // ✅ دالة إضافة دفعة محسّنة
  void _addPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          studentId: widget.studentId,
          onPaymentAdded: () {
            setState(() {
              _paymentsRefresh = !_paymentsRefresh;
            });
          },
          initialYear: _selectedYear == 0
              ? DateTime.now().year
              : _selectedYear, // 👈 تمرير السنة
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _paymentsRefresh = !_paymentsRefresh;
      });
    }
  }
  /*
  Widget _buildPaymentCard(PaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPaymentColor(
            payment.paymentType,
          ).withOpacity(0.1),
          child: Icon(
            _getPaymentIcon(payment.paymentType),
            color: _getPaymentColor(payment.paymentType),
            size: 20,
          ),
        ),
        title: Text(
          _formatPaymentName(payment),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(payment.paymentDate),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(0)} دج',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: payment.isGifted
                        ? Colors.green
                        : const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 4), // مسافة صغيرة لتنظيم المظهر
                // ✅ الـ Container الديناميكي المضاف لحالة الدفع
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPaymentStatusColor(payment).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getPaymentStatusText(payment),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getPaymentStatusColor(payment),
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => _deletePayment(payment.id!),
            ),
          ],
        ),

        onTap: () => _showPaymentDetails(payment),
      ),
    );
  }
*/

  Widget _buildPaymentCard(PaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPaymentColor(
            payment.paymentType,
          ).withOpacity(0.1),
          child: Icon(
            _getPaymentIcon(payment.paymentType),
            color: _getPaymentColor(payment.paymentType),
            size: 20,
          ),
        ),
        title: Text(
          _formatPaymentName(payment),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(payment.paymentDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getPaymentStatusColor(payment).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getPaymentStatusText(payment),
                style: TextStyle(
                  fontSize: 11,
                  color: _getPaymentStatusColor(payment),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        /*
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${payment.amount.toStringAsFixed(0)} دج',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: payment.isGifted
                    ? Colors.purple
                    : const Color(0xFFE53935),
              ),
            ),
          ],
        ),
       */
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ المبلغ
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${payment.amount.toStringAsFixed(0)} دج',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: payment.isGifted
                        ? Colors.purple
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
            // ✅ زر حذف الدفعة
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red,
              ),
              onPressed: () => _confirmDeletePayment(payment),
              tooltip: 'حذف الدفعة',
            ),
          ],
        ),

        onTap: () => _showPaymentDetails(payment),
      ),
    );
  }

  void _confirmDeletePayment(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف دفعة "${_formatPaymentName(payment)}" بقيمة ${payment.amount.toStringAsFixed(0)} دج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final repo = PaymentRepository(localDb: getIt());
              await repo.deletePayment(payment.id!);

              // إعادة تحميل البيانات
              _studentBloc.add(LoadStudentsEvent());
              setState(() {
                _paymentsRefresh = !_paymentsRefresh;
              });

              if (!mounted) return;
              Navigator.pop(context);
              CustomSnackbar.showSuccess(context, 'تم حذف الدفعة بنجاح');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Color _getPaymentColor(String type) {
    switch (type) {
      case 'monthly':
        return Colors.blue;
      case 'insurance':
        return Colors.green;
      case 'extra':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'monthly':
        return Icons.calendar_today;
      case 'insurance':
        return Icons.security;
      case 'extra':
        return Icons.shopping_bag;
      default:
        return Icons.payment;
    }
  }

  void _showPaymentDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الدفعة - ${payment.paymentTypeName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'المبلغ',
              '${payment.amount.toStringAsFixed(0)} دج',
            ),
            _buildDetailRow('التاريخ', _formatDate(payment.paymentDate)),
            if (payment.month != null)
              _buildDetailRow('الشهر', '${payment.month}'),
            if (payment.year != null)
              _buildDetailRow('السنة', '${payment.year}'),
            if (payment.extraReason != null)
              _buildDetailRow('السبب', payment.extraReason!),
            if (payment.isGifted) _buildDetailRow('نوع الدفعة', 'إهداء 🚀'),
            if (payment.notes != null)
              _buildDetailRow('ملاحظات', payment.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
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
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // إحصائيات الحضور التجريبية (لاحقاً ستجلب من قاعدة البيانات)
  Map<String, int> _getAttendanceStats() {
    // هذه بيانات تجريبية
    return {'أسبوع 1': 5, 'أسبوع 2': 4, 'أسبوع 3': 6, 'أسبوع 4': 5};
  }

  double _getAttendancePercentage() {
    final stats = _getAttendanceStats();
    final total = stats.values.fold(0, (sum, v) => sum + v);
    final maxPossible = stats.length * 6; // 6 حصص في الأسبوع
    if (maxPossible == 0) return 0;
    return (total / maxPossible) * 100;
  }
  /*
  Color _getPaymentStatusColor(PaymentModel payment) {
    if (payment.isGifted) return Colors.purple;
    if (payment.isFullyPaid) return Colors.green;
    if (payment.remainingAmount != null && payment.remainingAmount! > 0)
      return Colors.orange;
    if (payment.isPartial) return Colors.orange;
    return Colors.grey;
  }

  String _getPaymentStatusText(PaymentModel payment) {
    if (payment.isGifted) return 'إهداء';
    if (payment.isFullyPaid) return 'مكتمل ✓';
    if (payment.remainingAmount != null && payment.remainingAmount! > 0) {
      return 'متبقي: ${payment.remainingAmount!.toStringAsFixed(0)} دج';
    }
    if (payment.isPartial) return 'دفعة جزئية';
    return '';
  }
*/

  Color _getPaymentStatusColor(PaymentModel payment) {
    // إهداء
    if (payment.isGifted) {
      return Colors.purple;
    }

    // دفعة مسبقة أو مكتملة
    if (payment.prepaidMonths != null && payment.prepaidMonths! > 1) {
      return Colors.green;
    }

    if (payment.isFullyPaid) {
      return Colors.green;
    }

    // غير مكتمل (متبقي أو دفعة جزئية)
    if ((payment.remainingAmount != null && payment.remainingAmount! > 0) ||
        payment.isPartial) {
      return Colors.orange;
    }

    return Colors.grey;
  }

  String _getPaymentStatusText(PaymentModel payment) {
    // 1. إهداء
    if (payment.isGifted) {
      return 'إهداء 🎁';
    }

    // 2. دفعة مسبقة (عدة أشهر)
    if (payment.prepaidMonths != null && payment.prepaidMonths! > 1) {
      final startMonth = payment.prepaidStartMonth ?? payment.month;
      final startYear = payment.targetYear ?? payment.year;
      var endMonth = startMonth! + payment.prepaidMonths! - 1;
      var endYear = startYear;
      if (endMonth > 12) {
        endMonth -= 12;
        endYear = (endYear ?? 0) + 1;
      }
      return 'دفعة مسبقة (${payment.prepaidMonths} أشهر) ✓';
    }

    // 3. اشتراك شهري مكتمل
    if (payment.paymentType == 'monthly' && payment.isFullyPaid) {
      return 'مكتمل ✓';
    }

    // 4. اشتراك شهري غير مكتمل (متبقي)
    if (payment.paymentType == 'monthly' &&
        !payment.isFullyPaid &&
        payment.remainingAmount != null &&
        payment.remainingAmount! > 0) {
      return 'متبقي: ${payment.remainingAmount!.toStringAsFixed(0)} دج';
    }

    // 5. اشتراك شهري غير مكتمل (دفعة جزئية)
    if (payment.paymentType == 'monthly' && payment.isPartial) {
      return 'دفعة جزئية';
    }

    // 6. حقوق التأمين مكتملة
    if (payment.paymentType == 'insurance' && payment.isFullyPaid) {
      return 'مكتمل ✓';
    }

    // 7. حقوق التأمين غير مكتملة
    if (payment.paymentType == 'insurance' &&
        !payment.isFullyPaid &&
        payment.remainingAmount != null &&
        payment.remainingAmount! > 0) {
      return 'متبقي: ${payment.remainingAmount!.toStringAsFixed(0)} دج';
    }

    // 8. مستحقات إضافية
    if (payment.paymentType == 'extra') {
      if (payment.isGifted) {
        return 'إهداء 🎁';
      }
      return 'مستحقات إضافية';
    }

    // 9. الحالة الافتراضية
    return payment.isFullyPaid ? 'مكتمل ✓' : 'مسجل';
  }

  String _formatPaymentName(PaymentModel payment) {
    if (payment.paymentType == 'monthly') {
      if (payment.discountMonths != null && payment.discountMonths! > 1) {
        // دفعة مسبقة لعدة أشهر
        final startMonth = payment.targetMonth ?? payment.month;
        final endMonth = startMonth! + payment.discountMonths! - 1;
        return 'اشتراك أشهر $startMonth إلى $endMonth';
      } else {
        // شهر فردي
        return 'اشتراك شهر ${payment.targetMonth ?? payment.month}';
      }
    } else if (payment.paymentType == 'insurance') {
      return 'حقوق التسجيل ${payment.targetYear ?? payment.year}';
    } else if (payment.paymentType == 'extra') {
      return payment.extraReason ?? 'مستحقات إضافية';
    }
    return 'دفعة غير معروفة';
  }

  Future<void> _loadStudentBelts() async {
    final repo = BeltRepository(localDb: getIt());
    _studentBelts = await repo.getStudentBelts(widget.studentId);
    setState(() {});
  }
}
