// lib/presentation/screens/attendance_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/models/student_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/attendance_record.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../injection/dependency_injection.dart';
import 'student_absences_details_screen.dart';

class AttendanceStatsScreen extends StatefulWidget {
  const AttendanceStatsScreen({super.key});

  @override
  State<AttendanceStatsScreen> createState() => _AttendanceStatsScreenState();
}

class _AttendanceStatsScreenState extends State<AttendanceStatsScreen>
    with SingleTickerProviderStateMixin {
  late AttendanceRepository _attendanceRepo;
  late StudentRepository _studentRepo;
  late GroupRepository _groupRepo;

  // ==================== المتغيرات ====================
  List<StudentModel> _students = [];
  List<GroupModel> _groups = [];
  List<AttendanceRecord> _allRecords = [];

  // الفلاتر
  int? _selectedGroupId;
  String _searchQuery = '';
  int _filterType = 0; // 0=الكل, 1=أسبوعي, 2=شهري, 3=سنوي

  // بيانات الإحصائيات
  List<Map<String, dynamic>> _studentStats = [];
  bool _isLoading = true;
  bool _isLoadingStats = false;

  // اختيار التاريخ
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _showDateRangePicker = false;

  @override
  void initState() {
    super.initState();
    _attendanceRepo = AttendanceRepository(
      localDb: getIt(),
      remoteApi: getIt(),
      connectivity: getIt(),
    );
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _groupRepo = GroupRepository(localDb: getIt());
    _loadData();
  }

  // ==================== تحميل البيانات ====================
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _students = await _studentRepo.getAllStudents();
      _groups = await _groupRepo.getAllGroups();
      await _loadAllAttendance();
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
      CustomSnackbar.showError(context, 'خطأ في تحميل البيانات');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
// في _AttendanceStatsScreenState، أضف هذه الدالة:

  void _showStudentAbsences(
      StudentModel student, List<AttendanceRecord> records) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAbsencesDetailsScreen(
          student: student,
          records: records,
        ),
      ),
    );
  }

  // ==================== جلب جميع سجلات الحضور ====================
  Future<void> _loadAllAttendance() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      List<AttendanceRecord> allRecords = [];

      for (var student in _students) {
        final records = await _attendanceRepo.getStudentAttendance(
          studentId: student.id!,
          limit: 999,
        );
        allRecords.addAll(records);
      }

      _allRecords = allRecords;
      await _calculateStats();
    } catch (e) {
      print('❌ خطأ في جلب سجلات الحضور: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  // ==================== حساب الإحصائيات ====================
  Future<void> _calculateStats() async {
    // تصفية حسب الفوج
    var filteredStudents = _students;
    if (_selectedGroupId != null) {
      filteredStudents =
          filteredStudents.where((s) => s.groupId == _selectedGroupId).toList();
    }

    // تصفية حسب البحث
    if (_searchQuery.isNotEmpty) {
      filteredStudents = filteredStudents
          .where((s) => s.fullName.contains(_searchQuery))
          .toList();
    }

    // حساب الغيابات لكل طالب
    List<Map<String, dynamic>> stats = [];

    for (var student in filteredStudents) {
      // جلب سجلات الطالب
      final studentRecords =
          _allRecords.where((r) => r.studentId == student.id).toList();

      // تطبيق فلتر التاريخ
      final filteredRecords = _applyDateFilter(studentRecords);

      final total = filteredRecords.length;
      final present = filteredRecords.where((r) => r.isPresent).length;
      final absent = filteredRecords.where((r) => !r.isPresent).length;
      final rate = total > 0 ? (present / total) * 100 : 0;

      stats.add({
        'student': student,
        'total': total,
        'present': present,
        'absent': absent,
        'rate': rate,
        'records': filteredRecords,
      });
    }

    // ترتيب تنازلي حسب عدد الغيابات
    stats.sort((a, b) => (b['absent'] as int).compareTo(a['absent'] as int));

    setState(() {
      _studentStats = stats;
    });
  }

  // ==================== تطبيق فلتر التاريخ ====================
  List<AttendanceRecord> _applyDateFilter(List<AttendanceRecord> records) {
    if (_filterType == 0) return records; // الكل

    final now = DateTime.now();
    DateTime startDate;

    switch (_filterType) {
      case 1: // أسبوعي
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 2: // شهري
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 3: // سنوي
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return records;
    }

    return records
        .where((r) =>
            r.sessionDate != null &&
            r.sessionDate!.isAfter(startDate) &&
            r.sessionDate!.isBefore(now))
        .toList();
  }

  // ==================== تغيير الفلتر ====================
  void _onFilterChanged(int index) {
    setState(() {
      _filterType = index;
    });
    _calculateStats();
  }

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الغيابات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================== شريط الفلاتر ====================
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // صف الفلاتر
                Row(
                  children: [
                    // فلتر الفوج
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          labelText: 'الفوج',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('جميع الأفواج'),
                          ),
                          ..._groups.map((group) {
                            return DropdownMenuItem(
                              value: group.id,
                              child: Text(group.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGroupId = value;
                          });
                          _calculateStats();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // حقل البحث
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'بحث...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _calculateStats();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // أزرار الفلتر الزمني
                Row(
                  children: [
                    _buildFilterChip('الكل', 0),
                    const SizedBox(width: 4),
                    _buildFilterChip('أسبوعي', 1),
                    const SizedBox(width: 4),
                    _buildFilterChip('شهري', 2),
                    const SizedBox(width: 4),
                    _buildFilterChip('سنوي', 3),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ==================== المحتوى ====================
          Expanded(
            child: _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : _studentStats.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline,
                                size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد بيانات',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ==================== فلتر التشيب ====================
  Widget _buildFilterChip(String label, int index) {
    return Expanded(
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filterType == index,
        onSelected: (selected) {
          if (selected) _onFilterChanged(index);
        },
        selectedColor: const Color(0xFFE53935).withOpacity(0.2),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==================== محتوى الإحصائيات ====================
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ==================== إحصائيات سريعة ====================
          _buildQuickStats(),

          const SizedBox(height: 16),

          // ==================== الرسم البياني ====================
          _buildChart(),

          const SizedBox(height: 16),

          // ==================== قائمة الطلاب ====================
          _buildStudentsList(),
        ],
      ),
    );
  }

  // ==================== إحصائيات سريعة ====================
  Widget _buildQuickStats() {
    final totalAbsent =
        _studentStats.fold(0, (sum, s) => sum + (s['absent'] as int));
    final totalPresent =
        _studentStats.fold(0, (sum, s) => sum + (s['present'] as int));
    final totalRecords = totalAbsent + totalPresent;
    final totalStudents = _studentStats.length;
    final avgAbsent = totalStudents > 0 ? totalAbsent / totalStudents : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
              'الطلاب', totalStudents.toString(), Icons.people, Colors.white),
          _buildQuickStatItem(
              'الغيابات', totalAbsent.toString(), Icons.cancel, Colors.white70),
          _buildQuickStatItem(
              'متوسط الغيابات',
              '${avgAbsent.toStringAsFixed(1)}',
              Icons.trending_up,
              Colors.white70),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // ==================== الرسم البياني ====================
  Widget _buildChart() {
    final topStudents = _studentStats.take(10).toList();

    if (topStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'لا توجد بيانات للرسم البياني',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final maxAbsent = topStudents
        .map((s) => s['absent'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أكثر الطلاب غياباً (أعلى 10)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxAbsent + 2).toDouble(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < topStudents.length) {
                          final student =
                              topStudents[index]['student'] as StudentModel;
                          return Text(
                            student.firstName.length > 3
                                ? student.firstName.substring(0, 3)
                                : student.firstName,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                barGroups: topStudents.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final absent = data['absent'] as int;
                  final present = data['present'] as int;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: absent.toDouble(),
                        color: Colors.red,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: present.toDouble(),
                        color: Colors.green,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('الغياب', Colors.red),
              const SizedBox(width: 16),
              _buildLegendItem('الحضور', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ==================== قائمة الطلاب ====================
  Widget _buildStudentsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'قائمة الطلاب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_studentStats.length} طالب',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _studentStats.length > 20 ? 20 : _studentStats.length,
            itemBuilder: (context, index) {
              final data = _studentStats[index];
              final student = data['student'] as StudentModel;
              final absent = data['absent'] as int;
              final present = data['present'] as int;
              final total = data['total'] as int;
              final rate = data['rate'] as double;

              return InkWell(
                onTap: () {
                  final student = data['student'] as StudentModel;
                  final records = data['records'] as List<AttendanceRecord>;
                  _showStudentAbsences(student, records);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getAbsentColor(absent),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // الترتيب
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index < 3 ? Colors.amber : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  index < 3 ? Colors.black : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // اسم الطالب
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${total} حصة - نسبة الحضور ${rate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // عدد الغيابات
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getAbsentColor(absent).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${absent.toStringAsFixed(0)} غياب',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getAbsentColor(absent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_studentStats.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'عرض 20 طالب من أصل ${_studentStats.length}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== لون الغيابات ====================
  Color _getAbsentColor(int count) {
    if (count == 0) return Colors.green;
    if (count <= 2) return Colors.orange;
    if (count <= 5) return Colors.orange.shade700;
    return Colors.red;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
