// lib/presentation/screens/student_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../bloc/student/student_bloc.dart';
import '../bloc/student/events/student_event.dart';
import '../bloc/student/states/student_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
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

  @override
  void initState() {
    super.initState();
    _studentBloc = StudentBloc(getIt());
    _tabController = TabController(length: 6, vsync: this);
    _studentBloc.add(LoadStudentsEvent());
    // ✅ استدعاء دالة التحقق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDatabaseStructure();
    });
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
                  _buildSportsRecordTab(isMobile),
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
    return FutureBuilder<List<PaymentModel>>(
      key: ValueKey(_paymentsRefresh),
      future: _getStudentPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'خطأ: ${snapshot.error}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentsRefresh = !_paymentsRefresh;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
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
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد مدفوعات مسجلة',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                // زر الاختبار
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () async {
                      final db = await getIt<AppDatabase>().database;
                      final testPayment = {
                        'student_id': widget.studentId,
                        'amount': 1000,
                        'payment_date': DateTime.now().toIso8601String(),
                        'payment_type': 'monthly',
                        'month': DateTime.now().month,
                        'year': DateTime.now().year,
                        'is_extra': 0,
                        'is_gifted': 0,
                      };
                      final id = await db.insert('payments', testPayment);
                      print('🧪 تم إدراج دفعة اختبارية: id=$id');
                      setState(() {
                        _paymentsRefresh = !_paymentsRefresh;
                      });
                    },
                    child: const Text('🧪 إضافة دفعة اختبارية (1000 دج)'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentsRefresh = !_paymentsRefresh;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: _addPayment,
                    icon: const Icon(Icons.add),
                    label: const Text('تسجيل دفعة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _paymentsRefresh = !_paymentsRefresh;
            });
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // بطاقة الإجمالي
              Container(
                padding: const EdgeInsets.all(20),
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
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalPaid.toStringAsFixed(0)} دج',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'عدد الدفعات: ${payments.length}',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // قائمة الدفعات
              ...payments.map((payment) => _buildPaymentCard(payment)),

              const SizedBox(height: 16),

              // زر إضافة دفعة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add),
                  label: const Text('تسجيل دفعة جديدة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _paymentsRefresh = !_paymentsRefresh;
      });
    }
  }

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
          payment.paymentTypeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(payment.paymentDate),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
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
                    ? Colors.green
                    : const Color(0xFFE53935),
              ),
            ),
            if (payment.isGifted)
              const Text(
                'إهداء',
                style: TextStyle(fontSize: 10, color: Colors.green),
              ),
          ],
        ),
        onTap: () => _showPaymentDetails(payment),
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
}
