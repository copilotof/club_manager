// lib/presentation/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/models/hall_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/extra_session_model.dart';
import '../../data/repositories/hall_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';
import 'qr_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // ==================== المستودعات ====================
  late HallRepository _hallRepo;
  late GroupRepository _groupRepo;
  late StudentRepository _studentRepo;
  late AttendanceRepository _attendanceRepo;

  // ==================== المتغيرات الأساسية ====================
  DateTime _selectedDate = DateTime.now();

  // قوائم البيانات
  List<HallModel> _halls = [];
  List<GroupModel> _groups = [];
  List<SessionModel> _sessions = [];
  List<StudentModel> _students = [];
  List<AttendanceRecord> _records = [];

  // القيم المختارة
  int? _selectedHallId;
  int? _selectedGroupId;
  int? _selectedSessionId;

  // حالة التحميل
  bool _isLoading = true;
  bool _isLoadingData = false;
  bool _isSaving = false;
  bool _isCreatingExtraSession = false;

  // رسائل وأخطاء
  String _message = '';
  bool _hasSessions = false;
  bool _autoSelected = false;
  bool _isExtraSession = false;
  bool _isFieldsDisabled = false;

  // بيانات الحصة الاستثنائية
  ExtraSessionModel? _extraSession;

  // ==================== مفتاح الماسح الضوئي ====================
  final GlobalKey<QRScannerScreenState> _qrScannerKey =
      GlobalKey<QRScannerScreenState>();

  // ==================== الصوت ====================
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _hallRepo = HallRepository(localDb: getIt());
    _groupRepo = GroupRepository(localDb: getIt());
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _attendanceRepo = AttendanceRepository(
      localDb: getIt(),
      remoteApi: getIt(),
      connectivity: getIt(),
    );

    _initAudio();
    _loadAllData();
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
  }

  // ==================== تشغيل الأصوات ====================
  void _playBeep(String type) {
    try {
      HapticFeedback.mediumImpact();
      print('🔊 تشغيل صوت: $type');
    } catch (e) {
      print('⚠️ خطأ في تشغيل الصوت: $e');
    }
  }

  // ==================== تحميل جميع البيانات ====================
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري تحميل البيانات...';
      _isExtraSession = false;
      _isFieldsDisabled = false;
      _extraSession = null;
    });

    try {
      _halls = await _hallRepo.getAllHalls();

      if (_halls.isEmpty) {
        _message = '⚠️ لا توجد قاعات مسجلة. الرجاء إضافة قاعة في الإعدادات.';
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await _findSessionsByDate();

      // ✅ بعد تحميل البيانات، تحقق من صحة _selectedSessionId
      if (!_isExtraSession && _selectedSessionId != null) {
        final exists = _sessions.any((s) => s.id == _selectedSessionId!);
        if (!exists) {
          setState(() {
            _selectedSessionId =
                _sessions.isNotEmpty ? _sessions.first.id : null;
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
      _message = '❌ حدث خطأ في تحميل البيانات';
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== البحث عن الحصص حسب التاريخ ====================
/* 
 Future<void> _findSessionsByDate() async {
    setState(() {
      _isLoadingData = true;
      _message = 'جاري البحث عن حصص في هذا اليوم...';
      _isExtraSession = false;
      _isFieldsDisabled = false;
      _extraSession = null;
    });

    try {
      final selectedWeekday = _selectedDate.weekday;
      final sessionDayMap = {7: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6};
      final targetDay = sessionDayMap[selectedWeekday] ?? 0;

      List<SessionWithDetails> foundSessions = [];

      // ==================== 1. البحث عن الحصص العادية ====================
      for (var hall in _halls) {
        final groups = await _groupRepo.getGroupsByHall(hall.id!);

        for (var group in groups) {
          final sessions = await _groupRepo.getSessionsByGroup(group.id!);
          final daySessions =
              sessions.where((s) => s.dayOfWeek == targetDay).toList();

          for (var session in daySessions) {
            foundSessions.add(SessionWithDetails(
              hall: hall,
              group: group,
              session: session,
              isExtra: false,
            ));
          }
        }
      }

      // ==================== 2. البحث عن الحصص الاستثنائية ====================
      try {
        final db = await getIt<AppDatabase>().database;
        final dateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

        print('🔍 البحث عن حصة استثنائية في تاريخ: $dateStr');

        final extraResult = await db.query(
          'extra_sessions',
          where: 'date = ?',
          whereArgs: [dateStr],
        );

        print('📊 عدد الحصص الاستثنائية: ${extraResult.length}');

        for (var row in extraResult) {
          final extra = ExtraSessionModel.fromMap(row);
          print(
              '📝 حصة استثنائية: hall=${extra.hallId}, group=${extra.groupId}');

          final hall = _halls.firstWhere(
            (h) => h.id == extra.hallId,
            orElse: () => HallModel(id: extra.hallId, name: 'قاعة غير معروفة'),
          );

          final groups = await _groupRepo.getGroupsByHall(extra.hallId);
          final group = groups.firstWhere(
            (g) => g.id == extra.groupId,
            orElse: () => GroupModel(
              id: extra.groupId,
              hallId: extra.hallId,
              name: 'فوج غير معروف',
            ),
          );

          final tempSession = SessionModel(
            id: extra.id!,
            groupId: extra.groupId,
            dayOfWeek: targetDay,
            startTime: extra.startTime,
            endTime: extra.endTime,
          );

          // ✅ إضافة الحصة الاستثنائية إلى قائمة _sessions
          _sessions.add(tempSession);

          foundSessions.add(SessionWithDetails(
            hall: hall,
            group: group,
            session: tempSession,
            isExtra: true,
            extraReason: extra.reason,
            extraId: extra.id,
          ));
        }
      } catch (e) {
        print('⚠️ خطأ في البحث عن الحصص الاستثنائية: $e');
      }

      // ==================== 3. تحليل النتائج ====================
      if (foundSessions.isEmpty) {
  setState(() {
    _hasSessions = false;
    _message = '📅 لا توجد حصص تدريبية في يوم ${_formatDate(_selectedDate)}';
    _records = [];
    _students = [];
    _selectedHallId = null;
    _selectedGroupId = null;
    _selectedSessionId = null; // ✅ مسح القيمة المختارة
    _sessions = []; // ✅ مسح قائمة الحصص
    _isLoadingData = false;
    _isLoading = false;
  });
  return;
}

      // ✅ إذا كان هناك أكثر من حصة في نفس اليوم
      if (foundSessions.length > 1) {
        setState(() {
          _hasSessions = true;
          _isFieldsDisabled = false; // ✅ لا نعطل الحقول
          _autoSelected = false;
          _message =
              '📋 هناك ${foundSessions.length} حصص في هذا اليوم، اختر الحصة المناسبة';
          _selectedHallId = null;
          _selectedGroupId = null;
          _selectedSessionId = null;
        });

        // ✅ ملء قائمة _sessions بجميع الحصص
        _sessions = foundSessions.map((s) => s.session).toList();

        setState(() {
          _isLoadingData = false;
          _isLoading = false;
        });
        return;
      }

      // ✅ إذا كانت هناك حصة واحدة فقط
      if (foundSessions.length == 1) {
        final bestSession = foundSessions.first;

        setState(() {
          _selectedHallId = bestSession.hall.id;
          _selectedGroupId = bestSession.group.id;
          _selectedSessionId = bestSession.session.id;
          _autoSelected = true;
          _isExtraSession = bestSession.isExtra;
          _hasSessions = true;
          _isFieldsDisabled = true;

          if (bestSession.isExtra) {
            _extraSession = ExtraSessionModel(
              id: bestSession.extraId,
              date: _selectedDate,
              hallId: bestSession.hall.id!,
              groupId: bestSession.group.id!,
              startTime: bestSession.session.startTime,
              endTime: bestSession.session.endTime,
              reason: bestSession.extraReason,
              createdAt: DateTime.now(),
            );
          }
        });

        await _loadGroups(bestSession.hall.id!);
        await _loadSessionsForGroup(bestSession.group.id!);
        await _loadAttendance(bestSession.group.id!);

        String statusText = '';
        if (bestSession.isExtra) {
          statusText = ' 📝 حصة استثنائية';
          if (bestSession.extraReason != null &&
              bestSession.extraReason!.isNotEmpty) {
            statusText += ' - ${bestSession.extraReason}';
          }
        } else {
          final now = DateTime.now();
          if (_selectedDate.year == now.year &&
              _selectedDate.month == now.month &&
              _selectedDate.day == now.day) {
            statusText += ' ✓ الحصة الحالية';
          }
        }

        setState(() {
          _message =
              '✅ ${bestSession.hall.name} → ${bestSession.group.name} → ${bestSession.session.dayName} ${_formatTime(bestSession.session.startTime)} - ${_formatTime(bestSession.session.endTime)}$statusText';
          _isLoadingData = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في البحث عن الحصص: $e');
      setState(() {
        _message = '❌ حدث خطأ في البحث عن الحصص';
        _isLoadingData = false;
        _isLoading = false;
      });
    }
  }
 */

  Future<void> _findSessionsByDate() async {
    setState(() {
      _isLoadingData = true;
      _message = 'جاري البحث عن حصص في هذا اليوم...';
      _isExtraSession = false;
      _isFieldsDisabled = false;
      _extraSession = null;
      _sessions = []; // ✅ مسح القائمة أولاً
    });

    try {
      final selectedWeekday = _selectedDate.weekday;
      final sessionDayMap = {7: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6};
      final targetDay = sessionDayMap[selectedWeekday] ?? 0;

      List<SessionWithDetails> foundSessions = [];

      // 1. البحث عن الحصص العادية
      for (var hall in _halls) {
        final groups = await _groupRepo.getGroupsByHall(hall.id!);

        for (var group in groups) {
          final sessions = await _groupRepo.getSessionsByGroup(group.id!);
          final daySessions =
              sessions.where((s) => s.dayOfWeek == targetDay).toList();

          for (var session in daySessions) {
            foundSessions.add(SessionWithDetails(
              hall: hall,
              group: group,
              session: session,
              isExtra: false,
            ));
          }
        }
      }

      // 2. البحث عن الحصص الاستثنائية
      try {
        final db = await getIt<AppDatabase>().database;
        final dateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

        print('🔍 البحث عن حصة استثنائية في تاريخ: $dateStr');

        final extraResult = await db.query(
          'extra_sessions',
          where: 'date = ?',
          whereArgs: [dateStr],
        );

        print('📊 عدد الحصص الاستثنائية: ${extraResult.length}');

        for (var row in extraResult) {
          final extra = ExtraSessionModel.fromMap(row);
          print(
              '📝 حصة استثنائية: hall=${extra.hallId}, group=${extra.groupId}');

          final hall = _halls.firstWhere(
            (h) => h.id == extra.hallId,
            orElse: () => HallModel(id: extra.hallId, name: 'قاعة غير معروفة'),
          );

          final groups = await _groupRepo.getGroupsByHall(extra.hallId);
          final group = groups.firstWhere(
            (g) => g.id == extra.groupId,
            orElse: () => GroupModel(
              id: extra.groupId,
              hallId: extra.hallId,
              name: 'فوج غير معروف',
            ),
          );

          final tempSession = SessionModel(
            id: extra.id!,
            groupId: extra.groupId,
            dayOfWeek: targetDay,
            startTime: extra.startTime,
            endTime: extra.endTime,
          );

          _sessions.add(tempSession);

          foundSessions.add(SessionWithDetails(
            hall: hall,
            group: group,
            session: tempSession,
            isExtra: true,
            extraReason: extra.reason,
            extraId: extra.id,
          ));
        }
      } catch (e) {
        print('⚠️ خطأ في البحث عن الحصص الاستثنائية: $e');
      }

      // ==================== معالجة النتائج ====================
      if (foundSessions.isEmpty) {
        setState(() {
          _hasSessions = false;
          _message =
              '📅 لا توجد حصص تدريبية في يوم ${_formatDate(_selectedDate)}';
          _records = [];
          _students = [];
          _selectedHallId = null;
          _selectedGroupId = null;
          _selectedSessionId = null; // ✅ مسح القيمة المختارة
          _sessions = []; // ✅ مسح قائمة الحصص
          _isLoadingData = false;
          _isLoading = false;
        });
        return;
      }

      // ✅ إذا كان هناك أكثر من حصة في نفس اليوم
      if (foundSessions.length > 1) {
        setState(() {
          _hasSessions = true;
          _isFieldsDisabled = false;
          _autoSelected = false;
          _message =
              '📋 هناك ${foundSessions.length} حصص في هذا اليوم، اختر الحصة المناسبة';
          _selectedHallId = null;
          _selectedGroupId = null;
          _selectedSessionId = null;
          _sessions = foundSessions.map((s) => s.session).toList();
          _isLoadingData = false;
          _isLoading = false;
        });
        return;
      }

      // ✅ إذا كانت هناك حصة واحدة فقط
// ✅ إذا كانت هناك حصة واحدة فقط
      if (foundSessions.length == 1) {
        final bestSession = foundSessions.first;

        setState(() {
          _selectedHallId = bestSession.hall.id;
          _selectedGroupId = bestSession.group.id;
          _selectedSessionId = bestSession.session.id;
          _autoSelected = true;
          _isExtraSession = bestSession.isExtra;
          _hasSessions = true;
          // ✅ لا نعطل الحقول بالكامل، بل نعطل فقط حقل الحصة
          _isFieldsDisabled = false; // ✅ تغيير من true إلى false

          if (bestSession.isExtra) {
            _extraSession = ExtraSessionModel(
              id: bestSession.extraId,
              date: _selectedDate,
              hallId: bestSession.hall.id!,
              groupId: bestSession.group.id!,
              startTime: bestSession.session.startTime,
              endTime: bestSession.session.endTime,
              reason: bestSession.extraReason,
              createdAt: DateTime.now(),
            );
          }
        });

        await _loadGroups(bestSession.hall.id!);
        await _loadSessionsForGroupWithDate(
            bestSession.group.id!, _selectedDate); // ✅ استخدام الدالة الجديدة
        await _loadAttendance(bestSession.group.id!);

        String statusText = '';
        if (bestSession.isExtra) {
          statusText = ' 📝 حصة استثنائية';
          if (bestSession.extraReason != null &&
              bestSession.extraReason!.isNotEmpty) {
            statusText += ' - ${bestSession.extraReason}';
          }
        } else {
          final now = DateTime.now();
          if (_selectedDate.year == now.year &&
              _selectedDate.month == now.month &&
              _selectedDate.day == now.day) {
            statusText += ' ✓ الحصة الحالية';
          }
        }

        setState(() {
          _message =
              '✅ ${bestSession.hall.name} → ${bestSession.group.name} → ${bestSession.session.dayName} ${_formatTime(bestSession.session.startTime)} - ${_formatTime(bestSession.session.endTime)}$statusText';
          _isLoadingData = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في البحث عن الحصص: $e');
      setState(() {
        _message = '❌ حدث خطأ في البحث عن الحصص';
        _isLoadingData = false;
        _isLoading = false;
      });
    }
  }

  // ==================== تحميل الأفواج ====================
  Future<void> _loadGroups(int hallId) async {
    try {
      _groups = await _groupRepo.getGroupsByHall(hallId);
      setState(() {});
    } catch (e) {
      print('❌ خطأ في تحميل الأفواج: $e');
    }
  }

  // ==================== تحميل الحصص ====================
  Future<void> _loadSessionsForGroup(int groupId) async {
    try {
      // جلب الحصص العادية
      final regularSessions = await _groupRepo.getSessionsByGroup(groupId);

      // ✅ الاحتفاظ بالحصص الاستثنائية إذا كانت موجودة
      final extraSessions = _sessions.where((s) => s.id! < 0).toList();

      setState(() {
        // دمج الحصص العادية مع الاستثنائية
        _sessions = [...regularSessions, ...extraSessions];
      });
    } catch (e) {
      print('❌ خطأ في تحميل الحصص: $e');
    }
  }

  // ==================== تحميل الحضور ====================
  Future<void> _loadAttendance(int groupId) async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      _students = await _studentRepo.getStudentsByGroup(groupId);

      final records = await _attendanceRepo.getAttendanceForGroup(
        groupId: groupId,
        date: _selectedDate,
      );

      _records = _students.map((student) {
        final existing = records.firstWhere(
          (r) => r.studentId == student.id,
          orElse: () => AttendanceRecord(
            studentId: student.id!,
            studentName: student.firstName,
            studentLastName: student.lastName,
            beltColor: null,
            isPresent: false,
            wasAutoGenerated: true,
            markedAt: null,
            excuseReason: null,
          ),
        );
        return existing;
      }).toList();
    } catch (e) {
      print('❌ خطأ في تحميل الحضور: $e');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  // ==================== إنشاء حصة استثنائية ====================
  Future<void> _createExtraSession() async {
    if (_halls.isEmpty) {
      CustomSnackbar.showError(
          context, 'لا توجد قاعات. الرجاء إضافة قاعة في الإعدادات.');
      return;
    }

    int? selectedHallId = _halls.first.id;
    int? selectedGroupId;
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 30);
    String? reason;
    List<GroupModel> groups = [];

    try {
      groups = await _groupRepo.getGroupsByHall(selectedHallId!);
      if (groups.isNotEmpty) selectedGroupId = groups.first.id;
    } catch (e) {
      print('❌ خطأ في تحميل الأفواج: $e');
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('حصة استثنائية'),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'أنشئ حصة تدريبية استثنائية لهذا اليوم',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedHallId,
                      decoration: const InputDecoration(
                        labelText: 'القاعة *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: _halls.map((hall) {
                        return DropdownMenuItem(
                          value: hall.id,
                          child: Text(hall.name),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        selectedHallId = value;
                        if (value != null) {
                          final repo = GroupRepository(localDb: getIt());
                          groups = await repo.getGroupsByHall(value);
                          selectedGroupId =
                              groups.isNotEmpty ? groups.first.id : null;
                          setStateDialog(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'الفوج *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      items: groups.map((group) {
                        return DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedGroupId = value;
                        setStateDialog(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('وقت البداية *'),
                      subtitle: Text(
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: const MediaQueryData().copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          startTime = picked;
                          setStateDialog(() {});
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('وقت النهاية *'),
                      subtitle: Text(
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: const MediaQueryData().copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          endTime = picked;
                          setStateDialog(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'سبب الحصة الاستثنائية (اختياري)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        reason = value.trim().isEmpty ? null : value.trim();
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () async {
                  if (selectedHallId == null || selectedGroupId == null) {
                    CustomSnackbar.showError(
                        context, 'الرجاء اختيار القاعة والفوج');
                    return;
                  }

                  final db = await getIt<AppDatabase>().database;
                  final dateStr =
                      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

                  final existing = await db.query(
                    'extra_sessions',
                    where: 'date = ? AND hall_id = ? AND group_id = ?',
                    whereArgs: [dateStr, selectedHallId, selectedGroupId],
                  );

                  if (existing.isNotEmpty) {
                    CustomSnackbar.showError(context,
                        '⚠️ توجد حصة استثنائية مسجلة مسبقاً لهذا اليوم والقاعة والفوج');
                    return;
                  }

                  try {
                    final extraSession = ExtraSessionModel(
                      date: DateTime(_selectedDate.year, _selectedDate.month,
                          _selectedDate.day),
                      hallId: selectedHallId!,
                      groupId: selectedGroupId!,
                      startTime: startTime,
                      endTime: endTime,
                      reason: reason,
                      createdAt: DateTime.now(),
                    );

                    await db.insert('extra_sessions', extraSession.toMap());

                    Navigator.pop(context, {
                      'hallId': selectedHallId,
                      'groupId': selectedGroupId,
                      'startTime': startTime,
                      'endTime': endTime,
                      'reason': reason,
                    });

                    CustomSnackbar.showSuccess(
                        context, 'تم إنشاء الحصة الاستثنائية بنجاح');
                  } catch (e) {
                    print('❌ خطأ في حفظ الحصة الاستثنائية: $e');
                    CustomSnackbar.showError(
                        context, 'فشل حفظ الحصة الاستثنائية');
                  }
                },
                child: const Text('إنشاء'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await _loadAllData();
    }
  }

  // ==================== حذف الحصة الاستثنائية ====================
  Future<void> _deleteExtraSession() async {
    if (_extraSession == null) return;

    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'هل أنت متأكد من حذف الحصة الاستثنائية ليوم ${_formatDate(_selectedDate)}؟'),
            const SizedBox(height: 8),
            if (_extraSession!.reason != null)
              Text(
                'السبب: ${_extraSession!.reason}',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
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
      try {
        final db = await getIt<AppDatabase>().database;
        await db.delete(
          'extra_sessions',
          where: 'id = ?',
          whereArgs: [_extraSession!.id],
        );

        setState(() {
          _extraSession = null;
          _isExtraSession = false;
          _hasSessions = false;
          _isFieldsDisabled = false;
          _message = '🗑️ تم حذف الحصة الاستثنائية';
        });

        await _loadAllData();
        CustomSnackbar.showSuccess(context, 'تم حذف الحصة الاستثنائية بنجاح');
      } catch (e) {
        print('❌ خطأ في حذف الحصة الاستثنائية: $e');
        CustomSnackbar.showError(context, 'فشل حذف الحصة الاستثنائية');
      }
    }
  }

  // ==================== اختيار التاريخ ====================
  Future<void> _selectDate() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 280,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _selectedDate,
          maximumDate: DateTime.now(),
          minimumDate: DateTime(2020),
          onDateTimeChanged: (DateTime newDate) {
            setState(() {
              _selectedDate = newDate;
            });
          },
        ),
      ),
    ).then((_) {
      _loadAllData();
    });
  }

  // ==================== تغيير حالة الحضور ====================
  void _toggleAttendance(int index, {bool isPresent = true}) {
    setState(() {
      _records[index].isPresent = isPresent;
      _records[index].wasAutoGenerated = false;
      _records[index].markedAt = DateTime.now();
      if (isPresent) {
        _records[index].excuseReason = null;
      }
    });
    _saveAttendanceAutomatically();
  }

  // ==================== حفظ الحضور تلقائياً ====================
  Future<void> _saveAttendanceAutomatically() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      for (var record in _records) {
        if (!record.wasAutoGenerated) {
          if (record.isPresent) {
            await _attendanceRepo.markPresent(
              studentId: record.studentId,
              groupId: _selectedGroupId!,
              date: _selectedDate,
            );
          } else {
            await _attendanceRepo.markAbsent(
              studentId: record.studentId,
              groupId: _selectedGroupId!,
              date: _selectedDate,
              excuseReason: record.excuseReason,
            );
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في حفظ الحضور: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // ==================== عرض نافذة نتيجة QR ====================
  void _showQRResultDialog({
    required String studentId,
    required String studentName,
    required String studentLastName,
    required String status,
    VoidCallback? onConfirm,
  }) {
    Color backgroundColor;
    String icon;
    String message;
    String buttonText;

    switch (status) {
      case 'new':
        backgroundColor = Colors.green.shade700;
        icon = '✅';
        message = 'تسجيل الحضور';
        buttonText = 'حاضر';
        break;
      case 'duplicate':
        backgroundColor = Colors.orange.shade700;
        icon = '⚠️';
        message = 'تم تسجيل الحضور مسبقاً';
        buttonText = 'تم التسجيل';
        break;
      case 'not_found':
        backgroundColor = Colors.red.shade700;
        icon = '❌';
        message = 'غير موجود في هذا الفوج';
        buttonText = 'لا ينتمي';
        break;
      default:
        backgroundColor = Colors.grey.shade700;
        icon = 'ℹ️';
        message = 'غير معروف';
        buttonText = 'تم';
    }

    if (status == 'new') {
      _playBeep('success');
    } else if (status == 'duplicate') {
      _playBeep('warning');
    } else {
      _playBeep('error');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
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
              child: Text(
                icon,
                style: const TextStyle(fontSize: 40),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$studentName $studentLastName'.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  if (onConfirm != null) {
                    onConfirm();
                  }

                  // ✅ إعادة تفعيل المسح
                  _resumeScanner();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== إعادة تفعيل الماسح ====================
  void _resumeScanner() {
    print('🔄 محاولة إعادة تفعيل الماسح');
    if (_qrScannerKey.currentState != null) {
      _qrScannerKey.currentState!.resumeScanning();
      print('✅ تم إعادة تفعيل الماسح عبر الـ key');
    } else {
      print('⚠️ الـ key غير متاح');
    }
  }

  // ==================== معالجة نتيجة المسح ====================
  void _handleQRScan(ScanResult result) {
    print('📱 معالجة الكود: ${result.studentId}');

    final index =
        _records.indexWhere((r) => r.studentId.toString() == result.studentId);

    if (index != -1) {
      final record = _records[index];
      if (record.isPresent) {
        _showQRResultDialog(
          studentId: result.studentId,
          studentName: record.studentName,
          studentLastName: record.studentLastName,
          status: 'duplicate',
        );
      } else {
        _showQRResultDialog(
          studentId: result.studentId,
          studentName: record.studentName,
          studentLastName: record.studentLastName,
          status: 'new',
          onConfirm: () {
            _toggleAttendance(index, isPresent: true);
            _saveAttendanceAutomatically();
            _playBeep('success');
          },
        );
      }
    } else {
      _showQRResultDialog(
        studentId: result.studentId,
        studentName: 'طالب غير معروف',
        studentLastName: '',
        status: 'not_found',
      );
    }
  }

  // ==================== معالجة نتيجة المسح المتسلسل ====================
  Future<void> _handleQRScanResult(List<String> codes) async {
    int successCount = 0;
    int errorCount = 0;
    int alreadyPresentCount = 0;

    for (var code in codes) {
      final studentId = int.tryParse(code);
      if (studentId == null) continue;

      final index = _records.indexWhere((r) => r.studentId == studentId);

      if (index != -1) {
        if (_records[index].isPresent) {
          alreadyPresentCount++;
        } else {
          _toggleAttendance(index, isPresent: true);
          successCount++;
        }
      } else {
        errorCount++;
      }
    }

    String message = '';
    if (successCount > 0) message += '✅ تم تسجيل حضور $successCount طالب';
    if (alreadyPresentCount > 0)
      message += ' ⚠️ $alreadyPresentCount حاضر مسبقاً';
    if (errorCount > 0) message += ' ❌ $errorCount طالب غير موجود';

    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== مسح QR Code ====================
  Future<void> _scanQRCode() async {
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار حصة تدريبية أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerScreen(
            key: _qrScannerKey,
            title: 'مسح حضور الطلاب',
            continuousMode: true,
            totalStudents: _students.length,
            onScan: _handleQRScan,
          ),
        ),
      );

      if (result != null && mounted) {
        if (result is List<String> && result.isNotEmpty) {
          await _handleQRScanResult(result);
        }
      }
    } catch (e) {
      print('❌ خطأ في مسح QR Code: $e');
    }
  }

  // ==================== نافذة سبب الغياب ====================
  void _showExcuseDialog(int index) async {
    final controller =
        TextEditingController(text: _records[index].excuseReason);

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
                _records[index].excuseReason =
                    controller.text.isEmpty ? null : controller.text;
              });
              _saveAttendanceAutomatically();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ==================== دوال مساعدة ====================
  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'en_US').format(date);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getSessionTime(SessionModel session) {
    return '${session.dayName} - ${_formatTime(session.startTime)} إلى ${_formatTime(session.endTime)}';
  }

  String _getDayName(int weekday) {
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final index = weekday == 7 ? 0 : weekday;
    return days[index];
  }

  String _getSessionDisplayText() {
    if (_isFieldsDisabled) {
      // ✅ حصة استثنائية
      if (_isExtraSession && _extraSession != null) {
        final session = _extraSession!;
        final dayName = _getDayName(session.date.weekday);
        return '📝 حصة استثنائية: $dayName ${_formatTime(session.startTime)} - ${_formatTime(session.endTime)}';
      }

      // حصة عادية
      if (_selectedSessionId != null) {
        final session = _sessions.firstWhere(
          (s) => s.id == _selectedSessionId,
          orElse: () => SessionModel(
            id: 0,
            groupId: 0,
            dayOfWeek: 0,
            startTime: const TimeOfDay(hour: 0, minute: 0),
            endTime: const TimeOfDay(hour: 0, minute: 0),
          ),
        );
        if (session.id != 0) {
          return '${session.dayName} ${_formatTime(session.startTime)} - ${_formatTime(session.endTime)}';
        }
      }
      return 'تم التحديد تلقائياً';
    }

    return 'اختر حصة';
  }

  // ==================== إحصائيات الحضور ====================
  int get _presentCount => _records.where((r) => r.isPresent).length;
  int get _absentCount => _records.where((r) => !r.isPresent).length;
  double get _attendancePercentage =>
      _records.isEmpty ? 0 : (_presentCount / _records.length) * 100;

  // ==================== دوال لتغيير الحقول يدوياً ====================
  Future<void> _onHallChanged(int? hallId) async {
    if (hallId == null) return;
    setState(() {
      _selectedHallId = hallId;
      _selectedGroupId = null;
      _selectedSessionId = null;
      _groups = [];
      _sessions = [];
      _students = [];
      _records = [];
    });
    await _loadGroups(hallId);
  }

  Future<void> _onGroupChanged(int? groupId) async {
    if (groupId == null) return;
    setState(() {
      _selectedGroupId = groupId;
      _selectedSessionId = null;
      _sessions = [];
      _students = [];
      _records = [];
    });
    // ✅ تحميل الحصص الخاصة باليوم المختار فقط
    await _loadSessionsForGroupWithDate(groupId, _selectedDate);
    // await _loadSessionsForGroup(groupId);
  }

// ✅ دالة جديدة لتحميل الحصص حسب التاريخ
  Future<void> _loadSessionsForGroupWithDate(int groupId, DateTime date) async {
    try {
      // جلب جميع حصص الفوج
      final allSessions = await _groupRepo.getSessionsByGroup(groupId);

      // ✅ تصفية الحصص حسب اليوم المختار
      final selectedWeekday = date.weekday;
      final sessionDayMap = {7: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6};
      final targetDay = sessionDayMap[selectedWeekday] ?? 0;

      // جلب حصص اليوم المختار
      var daySessions =
          allSessions.where((s) => s.dayOfWeek == targetDay).toList();

      // ✅ إضافة الحصص الاستثنائية إذا كانت موجودة لهذا اليوم والفوج
      try {
        final db = await getIt<AppDatabase>().database;
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final extraResult = await db.query(
          'extra_sessions',
          where: 'date = ? AND group_id = ?',
          whereArgs: [dateStr, groupId],
        );

        for (var row in extraResult) {
          final extra = ExtraSessionModel.fromMap(row);
          final tempSession = SessionModel(
            id: extra.id!,
            groupId: extra.groupId,
            dayOfWeek: targetDay,
            startTime: extra.startTime,
            endTime: extra.endTime,
          );
          daySessions.add(tempSession);
        }
      } catch (e) {
        print('⚠️ خطأ في جلب الحصص الاستثنائية: $e');
      }

      setState(() {
        _sessions = daySessions;
      });

      // ✅ إذا كانت هناك حصة واحدة، اخترها تلقائياً
      if (_sessions.length == 1) {
        setState(() {
          _selectedSessionId = _sessions.first.id;
        });
        await _loadAttendance(groupId);
      } else if (_sessions.isEmpty) {
        setState(() {
          _selectedSessionId = null;
          _message = '📅 لا توجد حصص تدريبية في هذا اليوم لهذا الفوج';
        });
      } else {
        // ✅ إذا كانت هناك عدة حصص، اتركها كلها في القائمة
        setState(() {
          _selectedSessionId = null;
          _message =
              '📋 هناك ${_sessions.length} حصص في هذا اليوم، اختر الحصة المناسبة';
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الحصص: $e');
    }
  }

  Future<void> _onSessionChanged(int? sessionId) async {
    if (sessionId == null) return;
    setState(() {
      _selectedSessionId = sessionId;
    });
    if (_selectedGroupId != null) {
      await _loadAttendance(_selectedGroupId!);
    }
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
            InkWell(
              onTap: () =>
                  _toggleAttendance(index, isPresent: !record.isPresent),
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
                  if (!record.isPresent && record.excuseReason != null)
                    Text(
                      'العذر: ${record.excuseReason}',
                      style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: record.isPresent
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.isPresent ? 'حاضر' : 'غائب',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: record.isPresent ? Colors.green : Colors.red,
                ),
              ),
            ),
            if (!record.isPresent)
              IconButton(
                icon:
                    const Icon(Icons.edit_note, color: Colors.orange, size: 20),
                onPressed: () => _showExcuseDialog(index),
                tooltip: 'إضافة سبب الغياب',
              ),
          ],
        ),
      ),
    );
  }

  // ==================== عنصر الإحصائية ====================
  Widget _buildStatItem(
      String title, dynamic value, IconData icon, Color color) {
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

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    // ✅ حساب القيمة الصحيحة للـ Dropdown
    int? dropdownValue;

    if (_isExtraSession && _extraSession != null) {
      // إذا كانت حصة استثنائية، استخدم معرفها
      dropdownValue = _extraSession!.id;
    } else if (_selectedSessionId != null) {
      // تحقق من وجود الحصة في قائمة _sessions
      final sessionExists = _sessions.any((s) => s.id == _selectedSessionId!);
      dropdownValue = sessionExists ? _selectedSessionId : null;
    } else {
      dropdownValue = null;
    }

    return Scaffold(
/*       appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'مسح QR Code',
          ),
        ],
      ),
   */
/*       appBar: AppBar(
        title: Row(
          children: [
            const Text('تسجيل الحضور'),
            const Spacer(),
            Text(
              _formatDate(_selectedDate),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'mark_all_present':
                    for (int i = 0; i < _records.length; i++) {
                      if (!_records[i].isPresent) {
                        _toggleAttendance(i, isPresent: true);
                      }
                    }
                    CustomSnackbar.showSuccess(context, 'تم تسجيل حضور الجميع');
                    break;
                  case 'mark_all_absent':
                    for (int i = 0; i < _records.length; i++) {
                      if (_records[i].isPresent) {
                        _toggleAttendance(i, isPresent: false);
                      }
                    }
                    CustomSnackbar.showSuccess(context, 'تم تسجيل غياب الجميع');
                    break;
                  case 'delete_extra':
                    if (_isExtraSession) {
                      _deleteExtraSession();
                    } else {
                      CustomSnackbar.showWarning(
                          context, 'لا توجد حصة استثنائية');
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all_present',
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('حضور الجميع'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_all_absent',
                  child: Row(
                    children: const [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('غياب الجميع'),
                    ],
                  ),
                ),
                if (_isExtraSession)
                  PopupMenuItem(
                    value: 'delete_extra',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف الحصة الاستثنائية'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'مسح QR Code',
          ),
        ],
      ),
 */
/* 
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        actions: [
          // ✅ التاريخ والقائمة المنبثقة كأيقونات في الـ AppBar
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.normal),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            onSelected: (value) {
              switch (value) {
                case 'mark_all_present':
                  for (int i = 0; i < _records.length; i++) {
                    if (!_records[i].isPresent) {
                      _toggleAttendance(i, isPresent: true);
                    }
                  }
                  CustomSnackbar.showSuccess(context, 'تم تسجيل حضور الجميع');
                  break;
                case 'mark_all_absent':
                  for (int i = 0; i < _records.length; i++) {
                    if (_records[i].isPresent) {
                      _toggleAttendance(i, isPresent: false);
                    }
                  }
                  CustomSnackbar.showSuccess(context, 'تم تسجيل غياب الجميع');
                  break;
                case 'delete_extra':
                  if (_isExtraSession) {
                    _deleteExtraSession();
                  } else {
                    CustomSnackbar.showWarning(
                        context, 'لا توجد حصة استثنائية');
                  }
                  break;
                case 'change_date':
                  _selectDate();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('تغيير التاريخ'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_all_present',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('حضور الجميع'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_all_absent',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('غياب الجميع'),
                  ],
                ),
              ),
              if (_isExtraSession)
                const PopupMenuItem(
                  value: 'delete_extra',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف الحصة الاستثنائية'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'مسح QR Code',
          ),
        ],
      ),
 */
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'مسح QR Code',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                // ✅ اختيار التاريخ
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ✅ زر القائمة (ثلاث نقاط)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'mark_all_present':
                        for (int i = 0; i < _records.length; i++) {
                          if (!_records[i].isPresent) {
                            _toggleAttendance(i, isPresent: true);
                          }
                        }
                        CustomSnackbar.showSuccess(
                            context, 'تم تسجيل حضور الجميع');
                        break;
                      case 'mark_all_absent':
                        for (int i = 0; i < _records.length; i++) {
                          if (_records[i].isPresent) {
                            _toggleAttendance(i, isPresent: false);
                          }
                        }
                        CustomSnackbar.showSuccess(
                            context, 'تم تسجيل غياب الجميع');
                        break;
                      case 'create_extra':
                        _createExtraSession();
                        break;
                      case 'delete_extra':
                        if (_isExtraSession) {
                          _deleteExtraSession();
                        } else {
                          CustomSnackbar.showWarning(
                              context, 'لا توجد حصة استثنائية');
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'mark_all_present',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('حضور الجميع'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'mark_all_absent',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red),
                          SizedBox(width: 8),
                          Text('غياب الجميع'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'create_extra',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('إنشاء حصة استثنائية'),
                        ],
                      ),
                    ),
                    if (_isExtraSession)
                      const PopupMenuItem(
                        value: 'delete_extra',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف الحصة الاستثنائية'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== رسالة الحالة ====================
                  if (_message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _message.contains('✅')
                            ? Colors.green.shade50
                            : _message.contains('⚠️')
                                ? Colors.orange.shade50
                                : _message.contains('❌')
                                    ? Colors.red.shade50
                                    : _message.contains('📝')
                                        ? Colors.purple.shade50
                                        : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _message.contains('✅')
                              ? Colors.green.shade200
                              : _message.contains('⚠️')
                                  ? Colors.orange.shade200
                                  : _message.contains('❌')
                                      ? Colors.red.shade200
                                      : _message.contains('📝')
                                          ? Colors.purple.shade200
                                          : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _message.contains('✅')
                                ? Icons.check_circle
                                : _message.contains('⚠️')
                                    ? Icons.warning_amber
                                    : _message.contains('❌')
                                        ? Icons.error_outline
                                        : _message.contains('📝')
                                            ? Icons.edit_note
                                            : Icons.info_outline,
                            color: _message.contains('✅')
                                ? Colors.green.shade700
                                : _message.contains('⚠️')
                                    ? Colors.orange.shade700
                                    : _message.contains('❌')
                                        ? Colors.red.shade700
                                        : _message.contains('📝')
                                            ? Colors.purple.shade700
                                            : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message,
                              style: TextStyle(
                                fontSize: 13,
                                color: _message.contains('✅')
                                    ? Colors.green.shade700
                                    : _message.contains('⚠️')
                                        ? Colors.orange.shade700
                                        : _message.contains('❌')
                                            ? Colors.red.shade700
                                            : _message.contains('📝')
                                                ? Colors.purple.shade700
                                                : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

/*                   // ==================== أزرار الحصة الاستثنائية ====================
                  if (!_hasSessions && !_isExtraSession)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createExtraSession,
                            icon: const Icon(Icons.add_circle),
                            label: const Text('إنشاء حصة استثنائية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يمكنك إنشاء حصة استثنائية لهذا اليوم',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
 */
                  // ==================== زر حذف الحصة الاستثنائية ====================
/*                   if (_isExtraSession && _extraSession != null)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _deleteExtraSession,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('حذف الحصة الاستثنائية'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'حذف الحصة الاستثنائية لهذا اليوم',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
 */
                  // ==================== إذا كان هناك حصص ====================
                  if (_hasSessions) ...[
                    // اختيار القاعة
                    const Text('القاعة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedHallId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.business),
                        hintText: _isFieldsDisabled
                            ? 'تم التحديد تلقائياً'
                            : 'اختر قاعة',
                      ),
                      isExpanded: true,
                      items: _halls.map((hall) {
                        return DropdownMenuItem(
                          value: hall.id,
                          child: Text(hall.name),
                        );
                      }).toList(),
                      onChanged: _isFieldsDisabled ? null : _onHallChanged,
                    ),
                    const SizedBox(height: 12),

                    // اختيار الفوج
                    const Text('الفوج',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedGroupId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.group),
                        hintText: _isFieldsDisabled
                            ? 'تم التحديد تلقائياً'
                            : 'اختر فوج',
                      ),
                      isExpanded: true,
                      items: _groups.map((group) {
                        return DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        );
                      }).toList(),
                      onChanged: _isFieldsDisabled ? null : _onGroupChanged,
                    ),
                    const SizedBox(height: 12),

// ==================== اختيار الحصة ====================
                    const Text('الحصة التدريبية',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<int>(
                      value: dropdownValue,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.schedule),
                        // hintText: _getSessionDisplayText(),
                        hintText:
                            _sessions.isEmpty ? 'لا توجد حصص' : 'اختر حصة',
                      ),
                      isExpanded: true,
/*  
                      items: [
                        // ✅ إضافة خيار للحصة الاستثنائية
                        if (_isExtraSession && _extraSession != null)
                          DropdownMenuItem(
                            value: _extraSession!.id,
                            child: Text(
                              '📝 حصة استثنائية: ${_getDayName(_extraSession!.date.weekday)} ${_formatTime(_extraSession!.startTime)} - ${_formatTime(_extraSession!.endTime)}',
                            ),
                          ),
                        ..._sessions.map((session) {
                          return DropdownMenuItem(
                            value: session.id,
                            child: Text(_getSessionTime(session)),
                          );
                        }),
                      ],
   */
                      items: _sessions.map((session) {
                        return DropdownMenuItem(
                          value: session.id,
                          child: Text(_getSessionTime(session)),
                        );
                      }).toList(),
                      // onChanged: _isFieldsDisabled ? null : _onSessionChanged,
                      onChanged: _onSessionChanged,
                    ),

                    if (_isFieldsDisabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isExtraSession
                              ? '📝 حصة استثنائية'
                              : '🔒 تم التحديد تلقائياً',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isExtraSession
                                ? Colors.purple.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ==================== قائمة الحضور ====================
                    if (_selectedGroupId != null) ...[
                      if (_isLoadingData)
                        const Center(child: CircularProgressIndicator())
                      else if (_students.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 60, color: Colors.grey[400]),
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
                              _buildStatItem('الحضور', _presentCount,
                                  Icons.check_circle, Colors.white),
                              _buildStatItem('الغياب', _absentCount,
                                  Icons.cancel, Colors.white70),
                              _buildStatItem(
                                  'النسبة',
                                  '${_attendancePercentage.toStringAsFixed(0)}%',
                                  Icons.percent,
                                  Colors.white),
                            ],
                          ),
                        ),

/*                         // أزرار التحكم السريع
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  for (int i = 0; i < _records.length; i++) {
                                    if (!_records[i].isPresent) {
                                      _toggleAttendance(i, isPresent: true);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('حضور الجميع'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  for (int i = 0; i < _records.length; i++) {
                                    if (_records[i].isPresent) {
                                      _toggleAttendance(i, isPresent: false);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.cancel, size: 18),
                                label: const Text('غياب الجميع'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
    */
                        const SizedBox(height: 12),

                        // قائمة الطلاب
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            return _buildAttendanceCard(record, index);
                          },
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
}

// ==================== نموذج مساعد ====================
class SessionWithDetails {
  final HallModel hall;
  final GroupModel group;
  final SessionModel session;
  int priority = 999;
  final bool isExtra;
  final String? extraReason;
  final int? extraId;

  SessionWithDetails({
    required this.hall,
    required this.group,
    required this.session,
    this.isExtra = false,
    this.extraReason,
    this.extraId,
  });
}
