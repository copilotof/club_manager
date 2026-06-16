// lib/presentation/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/hall_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_record.dart';
import '../../data/repositories/hall_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
import 'qr_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late HallRepository _hallRepo;
  late GroupRepository _groupRepo;
  late StudentRepository _studentRepo;

  // ==================== المتغيرات ====================
  List<HallModel> _halls = [];
  List<GroupModel> _groups = [];
  List<SessionModel> _sessions = [];
  List<StudentModel> _students = [];
  List<AttendanceRecord> _records = [];

  int? _selectedHallId;
  int? _selectedGroupId;
  int? _selectedSessionId;

  bool _isLoading = true;
  bool _isLoadingGroups = false;
  bool _isLoadingSessions = false;
  bool _isLoadingStudents = false;

  // معلومات الاقتراح التلقائي
  String _autoSuggestionMessage = '';
  bool _autoSelected = false;

  String _filterType = 'all'; // 'all', 'present', 'absent'

  List<AttendanceRecord> get _filteredRecords {
    switch (_filterType) {
      case 'present':
        return _records.where((r) => r.isPresent).toList();
      case 'absent':
        return _records.where((r) => !r.isPresent).toList();
      default:
        return _records;
    }
  }

  @override
  void initState() {
    super.initState();
    _hallRepo = HallRepository(localDb: getIt());
    _groupRepo = GroupRepository(localDb: getIt());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _loadAndAutoSelect();
  }

  // ==================== التحميل والاختيار التلقائي ====================
  Future<void> _loadAndAutoSelect() async {
    setState(() {
      _isLoading = true;
      _autoSuggestionMessage = 'جاري البحث عن الحصة المناسبة...';
    });

    try {
      // 1. تحميل جميع القاعات
      _halls = await _hallRepo.getAllHalls();

      if (_halls.isEmpty) {
        _autoSuggestionMessage =
            '⚠️ لا توجد قاعات مسجلة. الرجاء إضافة قاعة في الإعدادات.';
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. تحميل جميع الأفواج والحصص والبحث عن الحصة المناسبة
      await _findBestSession();
    } catch (e) {
      print('❌ خطأ في التحميل: $e');
      _autoSuggestionMessage = '❌ حدث خطأ في تحميل البيانات';
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== البحث عن أفضل حصة (القاعة + الفوج + الحصة) ====================
  Future<void> _findBestSession() async {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // 1=الإثنين, 7=الأحد
    final currentTime = now.hour * 60 + now.minute; // الوقت بالدقائق

    // تحويل الأيام (للتطابق مع SessionModel حيث 0=الأحد)
    final sessionDayMap = {
      7: 0, // الأحد
      1: 1, // الإثنين
      2: 2, // الثلاثاء
      3: 3, // الأربعاء
      4: 4, // الخميس
      5: 5, // الجمعة
      6: 6, // السبت
    };
    final todaySessionDay = sessionDayMap[currentDayOfWeek];

    // هيكل لتخزين أفضل نتيجة
    BestSessionResult? bestResult;

    // 3. المرور على جميع القاعات
    for (var hall in _halls) {
      // جلب أفواج القاعة
      final groups = await _groupRepo.getGroupsByHall(hall.id!);

      for (var group in groups) {
        // جلب حصص الفوج
        final sessions = await _groupRepo.getSessionsByGroup(group.id!);

        // حصص اليوم الحالي فقط
        final todaySessions = sessions
            .where((s) => s.dayOfWeek == todaySessionDay)
            .toList();

        for (var session in todaySessions) {
          final sessionStartMinutes =
              session.startTime.hour * 60 + session.startTime.minute;
          final sessionEndMinutes =
              session.endTime.hour * 60 + session.endTime.minute;

          int priority;
          String status;

          // تحديد أولوية الحصة
          if (currentTime >= sessionStartMinutes &&
              currentTime <= sessionEndMinutes) {
            // حصة جارية الآن (أفضل أولوية)
            priority = 1;
            status = 'جارية الآن';
          } else if (sessionStartMinutes > currentTime) {
            // حصة قادمة (ثاني أفضل أولوية)
            priority = 2;
            status = 'قادمة';
          } else {
            // حصة انتهت (أقل أولوية)
            priority = 3;
            status = 'انتهت';
          }

          // حساب الفرق الزمني (للمقارنة بين الحصص القادمة)
          int timeDiff;
          if (sessionStartMinutes > currentTime) {
            timeDiff = sessionStartMinutes - currentTime;
          } else {
            timeDiff = 24 * 60 - (currentTime - sessionStartMinutes);
          }

          final result = BestSessionResult(
            hall: hall,
            group: group,
            session: session,
            priority: priority,
            timeDiff: timeDiff,
            status: status,
          );

          // مقارنة مع أفضل نتيجة حالية
          if (bestResult == null) {
            bestResult = result;
          } else if (result.priority < bestResult.priority) {
            bestResult = result;
          } else if (result.priority == bestResult.priority &&
              result.timeDiff < bestResult.timeDiff) {
            bestResult = result;
          }
        }
      }
    }

    // 4. تطبيق النتيجة الأفضل
    if (bestResult != null) {
      setState(() {
        _selectedHallId = bestResult!.hall.id;
        _selectedGroupId = bestResult!.group.id;
        _selectedSessionId = bestResult!.session.id;
        _autoSelected = true;
      });

      // بناء رسالة الاقتراح
      if (bestResult.status == 'جارية الآن') {
        _autoSuggestionMessage =
            '✓ الحصة الجارية الآن: ${bestResult.hall.name} → ${bestResult.group.name} → ${bestResult.session.dayName} ${_formatTime(bestResult.session.startTime)} - ${_formatTime(bestResult.session.endTime)}';
      } else if (bestResult.status == 'قادمة') {
        final hours = bestResult.timeDiff ~/ 60;
        final minutes = bestResult.timeDiff % 60;
        _autoSuggestionMessage =
            '⏰ الحصة القادمة بعد ${hours} ساعة و ${minutes} دقيقة: ${bestResult.hall.name} → ${bestResult.group.name} → ${bestResult.session.dayName} ${_formatTime(bestResult.session.startTime)} - ${_formatTime(bestResult.session.endTime)}';
      } else {
        _autoSuggestionMessage =
            '📅 آخر حصة لهذا اليوم: ${bestResult.hall.name} → ${bestResult.group.name} → ${bestResult.session.dayName} ${_formatTime(bestResult.session.startTime)} - ${_formatTime(bestResult.session.endTime)}';
      }

      // تحميل الأفواج والحصص والطلاب
      await _loadGroups(bestResult.hall.id!);
      await _loadSessionsForGroup(bestResult.group.id!);
      await _loadStudents(bestResult.group.id!);
    } else {
      _autoSuggestionMessage = '📅 لا توجد حصص تدريبية مسجلة لهذا اليوم';
    }

    setState(() {
      _isLoading = false;
    });
  }

  // ==================== تحميل الأفواج حسب القاعة ====================
  Future<void> _loadGroups(int hallId) async {
    setState(() {
      _isLoadingGroups = true;
    });

    try {
      _groups = await _groupRepo.getGroupsByHall(hallId);
    } catch (e) {
      print('❌ خطأ في تحميل الأفواج: $e');
    } finally {
      setState(() {
        _isLoadingGroups = false;
      });
    }
  }

  // ==================== تحميل الحصص لفوج معين ====================
  Future<void> _loadSessionsForGroup(int groupId) async {
    setState(() {
      _isLoadingSessions = true;
    });

    try {
      _sessions = await _groupRepo.getSessionsByGroup(groupId);
    } catch (e) {
      print('❌ خطأ في تحميل الحصص: $e');
    } finally {
      setState(() {
        _isLoadingSessions = false;
      });
    }
  }

  // ==================== تحميل طلاب الفوج ====================
  Future<void> _loadStudents(int groupId) async {
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      _students = await _studentRepo.getStudentsByGroup(groupId);

      _records = _students.map((student) {
        return AttendanceRecord(
          studentId: student.id!,
          studentName: student.firstName,
          studentLastName: student.lastName,
          beltColor: null,
          isPresent: false,
          wasAutoGenerated: true,
          markedAt: null,
          excuseReason: null,
        );
      }).toList();
    } catch (e) {
      print('❌ خطأ في تحميل الطلاب: $e');
    } finally {
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  // ==================== تغيير الحصة يدوياً ====================
  Future<void> _onSessionChanged(int? sessionId) async {
    if (sessionId == null) return;

    setState(() {
      _selectedSessionId = sessionId;
      _autoSelected = false;
      _autoSuggestionMessage = '';
    });

    if (_selectedGroupId != null) {
      await _loadStudents(_selectedGroupId!);
    }
  }

  // ==================== تغيير الفوج يدوياً ====================
  Future<void> _onGroupChanged(int? groupId) async {
    if (groupId == null) return;

    setState(() {
      _selectedGroupId = groupId;
      _selectedSessionId = null;
      _autoSelected = false;
      _autoSuggestionMessage = '';
      _sessions = [];
      _students = [];
      _records = [];
    });

    await _loadSessionsForGroup(groupId);
  }

  // ==================== تغيير القاعة يدوياً ====================
  Future<void> _onHallChanged(int? hallId) async {
    if (hallId == null) return;

    setState(() {
      _selectedHallId = hallId;
      _selectedGroupId = null;
      _selectedSessionId = null;
      _autoSelected = false;
      _autoSuggestionMessage = '';
      _groups = [];
      _sessions = [];
      _students = [];
      _records = [];
    });

    await _loadGroups(hallId);
  }

  // ==================== تغيير حالة الحضور ====================
  void _toggleAttendance(int index) {
    setState(() {
      _records[index].isPresent = !_records[index].isPresent;
      _records[index].wasAutoGenerated = false;
      _records[index].markedAt = DateTime.now();
      if (_records[index].isPresent) {
        _records[index].excuseReason = null;
      }
    });
  }

  // ==================== عرض نافذة سبب الغياب ====================
  void _showExcuseDialog(int index) async {
    final controller = TextEditingController(
      text: _records[index].excuseReason,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الغياب'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الغياب...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _records[index].excuseReason = controller.text.isEmpty
                    ? null
                    : controller.text;
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ==================== حفظ الحضور ====================
  Future<void> _saveAttendance() async {
    // TODO: حفظ سجلات الحضور في قاعدة البيانات
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الحضور بنجاح')));
  }

  // ==================== دوال مساعدة ====================
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getSessionTime(SessionModel session) {
    return '${session.dayName} - ${_formatTime(session.startTime)} إلى ${_formatTime(session.endTime)}';
  }

  // ==================== إحصائيات الحضور ====================
  int get _presentCount => _records.where((r) => r.isPresent).length;
  int get _absentCount => _records.where((r) => !r.isPresent).length;
  double get _attendancePercentage =>
      _records.isEmpty ? 0 : (_presentCount / _records.length) * 100;

  // ==================== مسح QR Code ====================
  Future<void> _scanQRCode() async {
    try {
      // ✅ فتح QR Scanner في وضع المسح المتسلسل
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const QRScannerScreen(
            title: 'مسح حضور الطلاب',
            continuousMode: true,
          ),
        ),
      );

      if (result != null && mounted) {
        // ✅ إذا كانت النتيجة قائمة (وضع المسح المتسلسل)
        if (result is List<String>) {
          int count = 0;
          for (var code in result) {
            final studentId = int.tryParse(code);
            if (studentId != null) {
              final index = _records.indexWhere(
                (r) => r.studentId == studentId,
              );
              if (index != -1) {
                _toggleAttendance(index);
                count++;
              }
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم تسجيل حضور $count طالب'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // ✅ إذا كانت النتيجة نص (وضع المسح العادي)
        else if (result is String) {
          final studentId = int.tryParse(result);
          if (studentId != null) {
            final index = _records.indexWhere((r) => r.studentId == studentId);
            if (index != -1) {
              _toggleAttendance(index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✓ تم تسجيل حضور ${_records[index].studentName}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في مسح QR Code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ حدث خطأ في مسح الكود'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== تسجيل حضور الجميع ====================
  void _markAllPresent() {
    setState(() {
      for (var record in _records) {
        record.isPresent = true;
        record.wasAutoGenerated = false;
        record.markedAt = DateTime.now();
        record.excuseReason = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ تم تسجيل حضور جميع الطلاب'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ==================== تسجيل غياب الجميع ====================
  void _markAllAbsent() {
    setState(() {
      for (var record in _records) {
        record.isPresent = false;
        record.wasAutoGenerated = false;
        record.markedAt = DateTime.now();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ تم تسجيل غياب جميع الطلاب'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'مسح QR Code',
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
                  // ==================== رسالة الاقتراح التلقائي ====================
                  if (_autoSuggestionMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _autoSelected
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _autoSelected
                              ? Colors.green.shade200
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoSelected
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 20,
                            color: _autoSelected
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _autoSuggestionMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: _autoSelected
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ==================== 1. اختيار القاعة ====================
                  const Text(
                    'القاعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedHallId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.business),
                      hintText: _halls.isEmpty ? 'لا توجد قاعات' : 'اختر قاعة',
                    ),
                    isExpanded: true,
                    items: _halls.map((hall) {
                      return DropdownMenuItem(
                        value: hall.id,
                        child: Text(hall.name),
                      );
                    }).toList(),
                    onChanged: _halls.isEmpty ? null : _onHallChanged,
                  ),

                  const SizedBox(height: 16),

                  // ==================== 2. اختيار الفوج ====================
                  if (_selectedHallId != null) ...[
                    const Text(
                      'الفوج',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingGroups)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                          hintText: _groups.isEmpty
                              ? 'لا توجد أفواج'
                              : 'اختر فوج',
                        ),
                        isExpanded: true,
                        items: _groups.map((group) {
                          return DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          );
                        }).toList(),
                        onChanged: _groups.isEmpty ? null : _onGroupChanged,
                      ),
                  ],

                  const SizedBox(height: 16),

                  // ==================== 3. اختيار الحصة ====================
                  if (_selectedGroupId != null) ...[
                    const Text(
                      'الحصة التدريبية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingSessions)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedSessionId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.schedule),
                          hintText: _sessions.isEmpty
                              ? 'لا توجد حصص'
                              : 'اختر حصة',
                        ),
                        isExpanded: true,
                        items: _sessions.map((session) {
                          return DropdownMenuItem(
                            value: session.id,
                            child: Text(_getSessionTime(session)),
                          );
                        }).toList(),
                        onChanged: _sessions.isEmpty ? null : _onSessionChanged,
                      ),
                  ],

                  const SizedBox(height: 24),

                  // ==================== 4. قائمة الحضور ====================
                  if (_selectedSessionId != null) ...[
                    if (_isLoadingStudents)
                      const Center(child: CircularProgressIndicator())
                    else if (_students.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد طلاب في هذا الفوج',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // إحصائيات الحضور
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                            _buildStatItem(
                              'الحضور',
                              _presentCount,
                              Icons.check_circle,
                              Colors.white,
                            ),
                            _buildStatItem(
                              'الغياب',
                              _absentCount,
                              Icons.cancel,
                              Colors.white70,
                            ),
                            _buildStatItem(
                              'النسبة',
                              '${_attendancePercentage.toStringAsFixed(0)}%',
                              Icons.percent,
                              Colors.white,
                            ),
                          ],
                        ),
                      ),
                      // ==================== أزرار التحكم السريع ====================
                      /*                       Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _markAllPresent,
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('حضور الجميع'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _markAllAbsent,
                                icon: const Icon(Icons.cancel, size: 18),
                                label: const Text('غياب الجميع'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
 */

                      // ==================== أزرار التحكم السريع والفلتر ====================
                      Column(
                        children: [
                          // أزرار حضور الجميع / غياب الجميع
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _markAllPresent,
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: const Text('حضور الجميع'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _markAllAbsent,
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text('غياب الجميع'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // أزرار الفلتر
                          Row(
                            children: [
                              _buildFilterChip('الكل', 'all'),
                              const SizedBox(width: 8),
                              _buildFilterChip('الحاضرون', 'present'),
                              const SizedBox(width: 8),
                              _buildFilterChip('الغائبون', 'absent'),
                            ],
                          ),
                        ],
                      ),

                      // قائمة الطلاب
                      /*                  ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          return _buildAttendanceCard(record, index);
                        },
                      ),
 */
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          final originalIndex = _records.indexWhere(
                            (r) => r.studentId == record.studentId,
                          );
                          return _buildAttendanceCard(record, originalIndex);
                        },
                      ),

                      const SizedBox(height: 16),

                      // زر الحفظ
                      ElevatedButton(
                        onPressed: _saveAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'حفظ الحضور',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Expanded(
      child: FilterChip(
        label: Text(label),
        selected: _filterType == value,
        onSelected: (selected) {
          setState(() {
            _filterType = value;
          });
        },
        selectedColor: const Color(0xFFE53935).withOpacity(0.2),
        backgroundColor: Colors.grey.shade100,
        labelStyle: TextStyle(
          color: _filterType == value
              ? const Color(0xFFE53935)
              : Colors.grey.shade700,
          fontWeight: _filterType == value
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    );
  }

  // ==================== عنصر الإحصائية ====================
  Widget _buildStatItem(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  // ==================== بطاقة حضور الطالب ====================
  Widget _buildAttendanceCard(AttendanceRecord record, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // أيقونة الحضور/الغياب
            InkWell(
              onTap: () => _toggleAttendance(index),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: record.isPresent
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  record.isPresent ? Icons.check : Icons.close,
                  color: record.isPresent ? Colors.green : Colors.red,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // معلومات الطالب
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.studentName} ${record.studentLastName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!record.isPresent && record.excuseReason != null)
                    Text(
                      'العذر: ${record.excuseReason}',
                      style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    ),
                ],
              ),
            ),

            // زر سبب الغياب (يظهر فقط للغياب)
            if (!record.isPresent)
              IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  color: Colors.orange,
                  size: 20,
                ),
                onPressed: () => _showExcuseDialog(index),
                tooltip: 'إضافة سبب الغياب',
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== نموذج لنتيجة البحث ====================
class BestSessionResult {
  final HallModel hall;
  final GroupModel group;
  final SessionModel session;
  final int priority; // 1: جارية, 2: قادمة, 3: منتهية
  final int timeDiff;
  final String status;

  BestSessionResult({
    required this.hall,
    required this.group,
    required this.session,
    required this.priority,
    required this.timeDiff,
    required this.status,
  });
}
