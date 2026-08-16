// lib/presentation/screens/attendance_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/group_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_record.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../injection/dependency_injection.dart';

class AttendanceStatsScreen extends StatefulWidget {
  const AttendanceStatsScreen({super.key});

  @override
  State<AttendanceStatsScreen> createState() => _AttendanceStatsScreenState();
}

class _AttendanceStatsScreenState extends State<AttendanceStatsScreen>
    with SingleTickerProviderStateMixin {
  late AttendanceRepository _attendanceRepo;
  late GroupRepository _groupRepo;
  late StudentRepository _studentRepo;

  List<GroupModel> _groups = [];
  List<StudentModel> _students = [];
  int? _selectedGroupId;
  int? _selectedStudentId;
  int _selectedTab = 0; // 0: حسب الفوج, 1: حسب الطالب
  int _selectedFilter = 0; // 0=أسبوعي, 1=شهري, 2=سنوي
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  // بيانات الإحصائيات
  List<Map<String, dynamic>> _statsData = [];
  Map<String, dynamic>? _studentStats;

  int? _filterGroupId;
  List<StudentModel> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _attendanceRepo = AttendanceRepository(
      localDb: getIt(),
      remoteApi: getIt(),
      connectivity: getIt(),
    );
    _groupRepo = GroupRepository(localDb: getIt());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _groups = await _groupRepo.getAllGroups();
      _students = await _studentRepo.getAllStudents();
      _filteredStudents = List.from(_students);

      if (_groups.isNotEmpty && _selectedGroupId == null) {
        _selectedGroupId = _groups.first.id;
      }

      if (_students.isNotEmpty && _selectedStudentId == null) {
        _selectedStudentId = _students.first.id;
      }

      await _loadStats();
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في تحميل البيانات');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (_selectedTab == 0 && _selectedGroupId == null) return;
    if (_selectedTab == 1 && _selectedStudentId == null) return;

    try {
      if (_selectedTab == 0) {
        // إحصائيات حسب الفوج
        final records = await _attendanceRepo.getAttendanceForGroupByDateRange(
          groupId: _selectedGroupId!,
          startDate: _getStartDate(),
          endDate: _getEndDate(),
        );
        _statsData = _processStats(records);
      } else {
        // إحصائيات حسب الطالب
        await _loadStudentStats(_selectedStudentId!);
      }
    } catch (e) {
      print('خطأ في تحميل الإحصائيات: $e');
    }
  }

// ==================== تحميل بيانات الطالب (المصحح) ====================
  Future<void> _loadStudentStats(int studentId) async {
    try {
      if (studentId == 0) {
        print('⚠️ studentId = 0، تخطي التحميل');
        return;
      }

      // ✅ التحقق من وجود الطالب
      final student = _students.firstWhere(
        (s) => s.id == studentId,
        orElse: () => StudentModel(
          firstName: '',
          lastName: '',
          birthDate: DateTime.now(),
          gender: '',
          enrollmentDate: DateTime.now(),
        ),
      );

      if (student.id == null || student.id == 0) {
        print('⚠️ الطالب غير موجود');
        return;
      }

      final records = await _attendanceRepo.getStudentAttendance(
        studentId: studentId,
        limit: 999,
      );

      print('📊 عدد سجلات الطالب ${student.fullName}: ${records.length}');

      int total = records.length;
      int present = records.where((r) => r.isPresent).length;
      int absent = records.where((r) => !r.isPresent).length;
      double attendanceRate = total > 0 ? (present / total) * 100 : 0;

      // ✅ إحصائيات الشهرية (مع تحويل آمن)
      Map<String, Map<String, dynamic>> monthlyStats = {};
      for (var record in records) {
        final key = DateFormat('yyyy-MM').format(record.sessionDate);
        if (!monthlyStats.containsKey(key)) {
          monthlyStats[key] = {'total': 0, 'present': 0, 'absent': 0};
        }
        monthlyStats[key]!['total'] = (monthlyStats[key]!['total'] as int) + 1;
        if (record.isPresent) {
          monthlyStats[key]!['present'] =
              (monthlyStats[key]!['present'] as int) + 1;
        } else {
          monthlyStats[key]!['absent'] =
              (monthlyStats[key]!['absent'] as int) + 1;
        }
      }

      setState(() {
        _studentStats = {
          'total': total,
          'present': present,
          'absent': absent,
          'rate': attendanceRate,
          'monthly': monthlyStats,
          'records': records,
        };
      });
    } catch (e) {
      print('❌ خطأ في تحميل إحصائيات الطالب: $e');
      setState(() {
        _studentStats = {
          'total': 0,
          'present': 0,
          'absent': 0,
          'rate': 0.0,
          'monthly': <String, Map<String, dynamic>>{},
          'records': <AttendanceRecord>[],
        };
      });
      // ✅ عرض رسالة خطأ للمستخدم
      CustomSnackbar.showError(context, 'خطأ في تحميل إحصائيات الطالب');
    }
  }

/*   Future<void> _loadStudentStats(int studentId) async {
    try {
      // ✅ التحقق من وجود studentId
      if (studentId == 0) {
        print('⚠️ studentId = 0، تخطي التحميل');
        return;
      }

      // جلب جميع سجلات حضور الطالب
      final records = await _attendanceRepo.getStudentAttendance(
        studentId: studentId,
        limit: 999,
      );

      print('📊 عدد سجلات الطالب: ${records.length}');

      // حساب الإحصائيات
      int total = records.length;
      int present = records.where((r) => r.isPresent).length;
      int absent = records.where((r) => !r.isPresent).length;
      double attendanceRate = total > 0 ? (present / total) * 100 : 0;

      // إحصائيات الشهرية
      Map<String, Map<String, dynamic>> monthlyStats = {};
      for (var record in records) {
        final key = DateFormat('yyyy-MM').format(record.sessionDate);
        if (!monthlyStats.containsKey(key)) {
          monthlyStats[key] = {'total': 0, 'present': 0, 'absent': 0};
        }
        monthlyStats[key]!['total'] = monthlyStats[key]!['total'] + 1;
        if (record.isPresent) {
          monthlyStats[key]!['present'] = monthlyStats[key]!['present'] + 1;
        } else {
          monthlyStats[key]!['absent'] = monthlyStats[key]!['absent'] + 1;
        }
      }

      setState(() {
        _studentStats = {
          'total': total,
          'present': present,
          'absent': absent,
          'rate': attendanceRate,
          'monthly': monthlyStats,
          'records': records,
        };
      });
    } catch (e) {
      print('❌ خطأ في تحميل إحصائيات الطالب: $e');
      setState(() {
        _studentStats = {
          'total': 0,
          'present': 0,
          'absent': 0,
          'rate': 0.0,
          'monthly': {},
          'records': [],
        };
      });
      CustomSnackbar.showError(context, 'خطأ في تحميل إحصائيات الطالب');
    }
  }
 */
// ==================== تحديث البيانات تلقائياً ====================
// في _onGroupChanged و _onStudentChanged، أضف:
  Future<void> _onFilterChanged() async {
    setState(() {
      _isLoading = true;
    });
    await _loadStats();
    setState(() {
      _isLoading = false;
    });
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 0: // أسبوعي
        return now.subtract(const Duration(days: 7));
      case 1: // شهري
        return DateTime(now.year, now.month - 1, now.day);
      default: // سنوي
        return DateTime(now.year - 1, now.month, now.day);
    }
  }

  DateTime _getEndDate() {
    return DateTime.now();
  }

  List<Map<String, dynamic>> _processStats(List<AttendanceRecord> records) {
    Map<String, Map<String, dynamic>> stats = {};

    for (var record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.sessionDate);

      if (!stats.containsKey(dateKey)) {
        stats[dateKey] = {
          'date': record.sessionDate,
          'total': 0,
          'present': 0,
          'absent': 0,
        };
      }

      stats[dateKey]!['total'] = stats[dateKey]!['total'] + 1;
      if (record.isPresent) {
        stats[dateKey]!['present'] = stats[dateKey]!['present'] + 1;
      } else {
        stats[dateKey]!['absent'] = stats[dateKey]!['absent'] + 1;
      }
    }

    return stats.values.toList();
  }

  // ==================== دوال إحصائيات الطالب ====================

/*   Widget _buildStudentQuickStats() {
    if (_studentStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _studentStats!;
    final total = stats['total'] as int;
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final rate = stats['rate'] as double;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'نسبة الحضور',
            '${rate.toStringAsFixed(1)}%',
            rate >= 70 ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الحاضرون',
            present.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الغائبون',
            absent.toString(),
            Colors.red,
          ),
        ),
      ],
    );
  }
 */

  Widget _buildStudentQuickStats() {
    if (_studentStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _studentStats!;
    final total = stats['total'] as int;
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final rate = stats['rate'] as double;

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
          _buildStudentStatItem(
              'الحضور', present.toString(), Icons.check_circle, Colors.white),
          _buildStudentStatItem(
              'الغياب', absent.toString(), Icons.cancel, Colors.white70),
          _buildStudentStatItem('النسبة', '${rate.toStringAsFixed(1)}%',
              Icons.percent, Colors.white),
          _buildStudentStatItem(
              'الإجمالي', total.toString(), Icons.people, Colors.white70),
        ],
      ),
    );
  }

  Widget _buildStudentStatItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ==================== عرض الرسم البياني للطالب ====================
  Widget _buildStudentChart() {
    if (_studentStats == null) return const SizedBox.shrink();

    final monthly =
        _studentStats!['monthly'] as Map<String, Map<String, dynamic>>;
    if (monthly.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'لا توجد بيانات كافية للرسم البياني',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final sortedKeys = monthly.keys.toList()..sort();

    return Container(
      height: 250,
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
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: monthly.values
                  .map((m) => (m['total'] as int))
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              2,
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
                  if (index >= 0 && index < sortedKeys.length) {
                    final key = sortedKeys[index];
                    return Text(
                      key.substring(5), // عرض الشهر فقط
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
          ),
          barGroups: sortedKeys.asMap().entries.map((entry) {
            final index = entry.key;
            final key = entry.value;
            final data = monthly[key]!;
            final total = data['total'] as int;
            final present = data['present'] as int;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: total.toDouble(),
                  color: Colors.blue,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: present.toDouble(),
                  color: Colors.green,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

/*   Widget _buildStudentChart() {
    if (_studentStats == null) return const SizedBox.shrink();

    final monthly =
        _studentStats!['monthly'] as Map<String, Map<String, dynamic>>;
    if (monthly.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'لا توجد بيانات كافية للرسم البياني',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final sortedKeys = monthly.keys.toList()..sort();

    return Container(
      height: 250,
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
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: monthly.values
                  .map((m) => m['total'] as int)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              2,
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
                  if (index >= 0 && index < sortedKeys.length) {
                    final key = sortedKeys[index];
                    return Text(
                      key.substring(5), // عرض الشهر فقط
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
          ),
          barGroups: sortedKeys.asMap().entries.map((entry) {
            final index = entry.key;
            final key = entry.value;
            final data = monthly[key]!;
            final total = data['total'] as int;
            final present = data['present'] as int;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: total.toDouble(),
                  color: Colors.blue,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: present.toDouble(),
                  color: Colors.green,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
 */
  Widget _buildStudentDetailsTable() {
    if (_studentStats == null) return const SizedBox.shrink();

    final records = _studentStats!['records'] as List<AttendanceRecord>;
    if (records.isEmpty) {
      return const Center(child: Text('لا توجد سجلات حضور'));
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الملاحظات')),
          ],
          rows: records.map((record) {
            return DataRow(
              cells: [
                DataCell(
                    Text(DateFormat('yyyy/MM/dd').format(record.sessionDate))),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.isPresent
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.isPresent ? 'حاضر' : 'غائب',
                      style: TextStyle(
                        color: record.isPresent ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(record.excuseReason ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== واجهة المستخدم ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الغيابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== تبويبات ====================
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTab = 0;
                            });
                            _loadStats();
                          },
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
                              'حسب الفوج',
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
                          onTap: () {
                            setState(() {
                              _selectedTab = 1;
                            });
                            _loadStats();
                          },
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
                              'حسب الطالب',
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

                  const SizedBox(height: 16),

                  // ==================== المحتوى حسب التبويب ====================
                  if (_selectedTab == 0) _buildGroupFilter(),
                  if (_selectedTab == 1) _buildStudentFilter(),

                  const SizedBox(height: 16),

                  // ==================== فلتر الفترة ====================
                  _buildPeriodFilter(),

                  const SizedBox(height: 16),

                  // ==================== الإحصائيات ====================
                  if (_selectedTab == 0) _buildGroupStats(),
                  if (_selectedTab == 1) _buildStudentStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupFilter() {
    return DropdownButtonFormField<int>(
      value: _selectedGroupId,
      decoration: InputDecoration(
        labelText: 'الفوج',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.group),
      ),
      items: [
        ..._groups.map((group) {
          return DropdownMenuItem(
            value: group.id,
            child: Text(group.name),
          );
        }),
      ],
      onChanged: (value) async {
        setState(() {
          _selectedGroupId = value;
        });
        await _loadStats();
      },
    );
  }

// ==================== تصفية الطلاب حسب الفوج ====================
  Future<void> _filterStudentsByGroup(int? groupId) async {
    setState(() {
      _filterGroupId = groupId;
    });

    if (groupId == null) {
      _filteredStudents = List.from(_students);
    } else {
      _filteredStudents = _students.where((s) => s.groupId == groupId).toList();
    }

    // ✅ تحديث الطالب المختار إذا كان خارج القائمة
    if (_selectedStudentId != null &&
        !_filteredStudents.any((s) => s.id == _selectedStudentId)) {
      setState(() {
        _selectedStudentId =
            _filteredStudents.isNotEmpty ? _filteredStudents.first.id : null;
      });
      await _loadStats();
    } else {
      setState(() {});
    }
  }

// ==================== فلتر الطلاب مع البحث ====================
  Widget _buildStudentFilter() {
    return Column(
      children: [
        // فلتر الفوج
        DropdownButtonFormField<int>(
          value: _filterGroupId,
          decoration: InputDecoration(
            labelText: 'الفوج',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.group),
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
          onChanged: (value) async {
            await _filterStudentsByGroup(value);
          },
        ),
        const SizedBox(height: 12),

        // ✅ اختيار الطالب مع إمكانية البحث
        Autocomplete<int>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _filteredStudents.map((s) => s.id!).toList();
            }
            return _filteredStudents
                .where((s) => s.fullName.contains(textEditingValue.text))
                .map((s) => s.id!)
                .toList();
          },
          displayStringForOption: (id) {
            final student = _filteredStudents.firstWhere((s) => s.id == id);
            return student.fullName;
          },
          onSelected: (value) async {
            setState(() {
              _selectedStudentId = value;
            });
            await _loadStats();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'البحث عن طالب...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setState(() {
                            _selectedStudentId = null;
                          });
                        },
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPeriodFilter() {
    return Row(
      children: [
        _buildFilterChip('أسبوعي', 0),
        const SizedBox(width: 8),
        _buildFilterChip('شهري', 1),
        const SizedBox(width: 8),
        _buildFilterChip('سنوي', 2),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    return Expanded(
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == index,
        onSelected: (selected) async {
          setState(() {
            _selectedFilter = index;
          });
          await _loadStats();
        },
        selectedColor: const Color(0xFFE53935).withOpacity(0.2),
      ),
    );
  }

  Widget _buildGroupStats() {
    if (_statsData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'لا توجد بيانات كافية',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: [
        _buildQuickStats(),
        const SizedBox(height: 16),
        _buildChart(),
        const SizedBox(height: 16),
        _buildDataTable(),
      ],
    );
  }

  Widget _buildStudentStats() {
    if (_studentStats == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        _buildStudentQuickStats(),
        const SizedBox(height: 16),
        _buildStudentChart(),
        const SizedBox(height: 16),
        _buildStudentDetailsTable(),
      ],
    );
  }

  Widget _buildQuickStats() {
    if (_statsData.isEmpty) {
      return const SizedBox.shrink();
    }

    int total = _statsData.fold(0, (sum, item) => sum + (item['total'] as int));
    int present =
        _statsData.fold(0, (sum, item) => sum + (item['present'] as int));
    int absent =
        _statsData.fold(0, (sum, item) => sum + (item['absent'] as int));
    double attendanceRate = total > 0 ? (present / total) * 100 : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'نسبة الحضور',
            '${attendanceRate.toStringAsFixed(1)}%',
            attendanceRate >= 70 ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الحاضرون',
            present.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الغائبون',
            absent.toString(),
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_statsData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'لا توجد بيانات كافية للرسم البياني',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Container(
      height: 250,
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
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _statsData
                  .map((item) => item['total'] as int)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              2,
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
                  if (index >= 0 && index < _statsData.length) {
                    final date = _statsData[index]['date'] as DateTime;
                    return Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
          ),
          barGroups: _statsData.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final total = item['total'] as int;
            final present = item['present'] as int;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: total.toDouble(),
                  color: Colors.blue,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: present.toDouble(),
                  color: Colors.green,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_statsData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('الإجمالي')),
            DataColumn(label: Text('الحاضرون')),
            DataColumn(label: Text('الغائبون')),
            DataColumn(label: Text('نسبة الحضور')),
          ],
          rows: _statsData.map((item) {
            final date = item['date'] as DateTime;
            final total = item['total'] as int;
            final present = item['present'] as int;
            final absent = item['absent'] as int;
            final rate = total > 0 ? (present / total) * 100 : 0;

            return DataRow(
              cells: [
                DataCell(Text(DateFormat('yyyy/MM/dd').format(date))),
                DataCell(Text(total.toString())),
                DataCell(Text(present.toString())),
                DataCell(Text(absent.toString())),
                DataCell(
                  Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: rate >= 70 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
