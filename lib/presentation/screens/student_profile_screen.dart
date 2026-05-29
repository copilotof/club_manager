// lib/presentation/screens/student_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/student_model.dart';
import '../bloc/student/student_bloc.dart';
import '../bloc/student/events/student_event.dart';
import '../bloc/student/states/student_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
import 'add_edit_student_screen.dart';
import 'package:fl_chart/fl_chart.dart';

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
  StudentModel? _student;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _studentBloc = StudentBloc(getIt());
    _tabController = TabController(length: 6, vsync: this);
    _studentBloc.add(LoadStudentsEvent());
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
              Tab(text: 'معلومات دراسية', icon: Icon(Icons.school)),
              Tab(text: 'معلومات صحية', icon: Icon(Icons.health_and_safety)),
              Tab(text: 'السجل الرياضي', icon: Icon(Icons.emoji_events)),
              Tab(text: 'المدفوعات', icon: Icon(Icons.payments)),
              Tab(text: '📊 إحصائيات', icon: Icon(Icons.bar_chart)),
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
                  _buildAcademicInfoTab(isMobile),
                  _buildHealthInfoTab(isMobile),
                  _buildSportsRecordTab(isMobile),
                  _buildPaymentsTab(isMobile),
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

  Widget _buildPaymentsTab(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'سجل المدفوعات',
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
