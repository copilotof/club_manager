// lib/presentation/screens/student_absences_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_record.dart';

class StudentAbsencesDetailsScreen extends StatefulWidget {
  final StudentModel student;
  final List<AttendanceRecord> records;

  const StudentAbsencesDetailsScreen({
    super.key,
    required this.student,
    required this.records,
  });

  @override
  State<StudentAbsencesDetailsScreen> createState() =>
      _StudentAbsencesDetailsScreenState();
}

class _StudentAbsencesDetailsScreenState
    extends State<StudentAbsencesDetailsScreen> {
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _calculateAvailableYears();
  }

  void _calculateAvailableYears() {
    final enrollmentYear = widget.student.enrollmentDate.year;
    final currentYear = DateTime.now().year;
    _availableYears = [];
    for (int year = enrollmentYear; year <= currentYear; year++) {
      _availableYears.add(year);
    }
    // ترتيب تنازلي (الأحدث أولاً)
    _availableYears.sort((a, b) => b.compareTo(a));
    if (_availableYears.isNotEmpty) {
      _selectedYear = _availableYears.first;
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    return widget.records
        .where((r) =>
            r.sessionDate != null && r.sessionDate!.year == _selectedYear)
        .toList();
  }

  List<AttendanceRecord> get _absences {
    return _filteredRecords.where((r) => !r.isPresent).toList();
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('yyyy/MM/dd', 'en_US').format(date);
    } catch (e) {
      return '--/--/----';
    }
  }

  String _getDayName(DateTime date) {
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final index = date.weekday == 7 ? 0 : date.weekday;
    return days[index];
  }

  @override
  Widget build(BuildContext context) {
    final absences = _absences;
    final totalRecords = _filteredRecords.length;
    final totalAbsences = absences.length;
    final absenceRate =
        totalRecords > 0 ? (totalAbsences / totalRecords) * 100 : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الغيابات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // زر تصفية السنة
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: _availableYears.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== معلومات الطالب ====================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFC62828)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          widget.student.firstName[0],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تاريخ التسجيل: ${_formatDate(widget.student.enrollmentDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              'العمر: ${widget.student.age} سنة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // إحصائيات سريعة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'إجمالي الحصص',
                        totalRecords.toString(),
                        Icons.calendar_today,
                        Colors.white70,
                      ),
                      _buildStatItem(
                        'الغيابات',
                        totalAbsences.toString(),
                        Icons.cancel,
                        Colors.orangeAccent,
                      ),
                      _buildStatItem(
                        'نسبة الغياب',
                        '${absenceRate.toStringAsFixed(1)}%',
                        Icons.percent,
                        absenceRate > 30 ? Colors.redAccent : Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ==================== قائمة الغيابات ====================
            Container(
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
                        'سجل الغيابات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: totalAbsences > 0
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          totalAbsences > 0
                              ? '$totalAbsences غياب'
                              : 'لا يوجد غيابات',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                totalAbsences > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (absences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '🎉 لا توجد غيابات',
                          style: TextStyle(fontSize: 16, color: Colors.green),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: absences.length,
                      itemBuilder: (context, index) {
                        final absence = absences[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: absence.wasAutoGenerated
                                  ? Colors.orange.shade200
                                  : Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // الأيقونة
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: absence.wasAutoGenerated
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  absence.wasAutoGenerated
                                      ? Icons.warning_amber
                                      : Icons.cancel,
                                  color: absence.wasAutoGenerated
                                      ? Colors.orange
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // التاريخ
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getDayName(absence.sessionDate!)} ${_formatDate(absence.sessionDate!)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (absence.excuseReason != null)
                                      Text(
                                        'العذر: ${absence.excuseReason}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // نوع الغياب
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: absence.wasAutoGenerated
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  absence.wasAutoGenerated ? 'تلقائي' : 'يدوي',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: absence.wasAutoGenerated
                                        ? Colors.orange
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
