// lib/presentation/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
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

  // بيانات الحصة الاستثنائية المحفوظة
  ExtraSessionModel? _extraSession;

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

    _loadAllData();
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

      // التحقق من وجود حصة استثنائية لهذا اليوم
      await _checkExtraSession();

      // إذا لم توجد حصة استثنائية، ابحث عن الحصص العادية
      if (_extraSession == null) {
        await _findSessionsByDate();
      }
      // عند وجود حصة استثنائية من البداية
      if (_extraSession != null) {
        String extraMessage = '📝 حصة استثنائية';
        if (_extraSession!.reason != null &&
            _extraSession!.reason!.isNotEmpty) {
          extraMessage += ' - ${_extraSession!.reason}';
        } else {
          extraMessage += ' (${_formatDate(_selectedDate)})';
        }
        _message = extraMessage;
      }
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
      _message = '❌ حدث خطأ في تحميل البيانات';
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== التحقق من وجود حصة استثنائية ====================
  Future<void> _checkExtraSession() async {
    try {
      final db = await getIt<AppDatabase>().database;

      // ✅ توحيد تنسيق التاريخ
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final result = await db.query(
        'extra_sessions',
        where: 'date = ?',
        whereArgs: [dateStr],
      );

      if (result.isNotEmpty) {
        _extraSession = ExtraSessionModel.fromMap(result.first);
        _isExtraSession = true;
        _hasSessions = true;
        _isFieldsDisabled = true; // تعطيل الحقول

        _selectedHallId = _extraSession!.hallId;
        _selectedGroupId = _extraSession!.groupId;

        // تحميل البيانات
        await _loadGroups(_extraSession!.hallId);
        await _loadSessionsForGroup(_extraSession!.groupId);
        await _loadAttendance(_extraSession!.groupId);

// عرض سبب الحصة الاستثنائية بدلاً من التاريخ
        String extraMessage = '📝 حصة استثنائية';
        if (_extraSession != null &&
            _extraSession!.reason != null &&
            _extraSession!.reason!.isNotEmpty) {
          extraMessage += ' - ${_extraSession!.reason}';
        } else {
          extraMessage += ' (${_formatDate(_selectedDate)})';
        }
        _message = extraMessage;
        if (_extraSession!.reason != null) {
          _message += ' - السبب: ${_extraSession!.reason}';
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في التحقق من الحصة الاستثنائية: $e');
    }
  }

  // ==================== البحث عن الحصص حسب التاريخ (بما فيها الاستثنائية) ====================
  // ==================== البحث عن الحصص حسب التاريخ ====================
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
            foundSessions.add(
              SessionWithDetails(
                hall: hall,
                group: group,
                session: session,
                isExtra: false,
              ),
            );
          }
        }
      }

      // ==================== 2. البحث عن الحصص الاستثنائية ====================
      try {
        final db = await getIt<AppDatabase>().database;
        // ✅ توحيد تنسيق التاريخ
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
            '📝 حصة استثنائية: hall=${extra.hallId}, group=${extra.groupId}, start=${extra.startTime}, end=${extra.endTime}',
          );

          // جلب القاعة
          final hall = _halls.firstWhere(
            (h) => h.id == extra.hallId,
            orElse: () => HallModel(id: extra.hallId, name: 'قاعة غير معروفة'),
          );

          // جلب الفوج
          final groups = await _groupRepo.getGroupsByHall(extra.hallId);
          final group = groups.firstWhere(
            (g) => g.id == extra.groupId,
            orElse: () => GroupModel(
              id: extra.groupId,
              hallId: extra.hallId,
              name: 'فوج غير معروف',
            ),
          );

          // إنشاء SessionModel مؤقت للحصة الاستثنائية
          final tempSession = SessionModel(
            id: -extra.id!, // قيمة سالبة للتمييز
            groupId: extra.groupId,
            dayOfWeek: targetDay,
            startTime: extra.startTime,
            endTime: extra.endTime,
          );

          foundSessions.add(
            SessionWithDetails(
              hall: hall,
              group: group,
              session: tempSession,
              isExtra: true,
              extraReason: extra.reason,
              extraId: extra.id,
            ),
          );
        }
      } catch (e) {
        print('⚠️ خطأ في البحث عن الحصص الاستثنائية: $e');
      }

      // ==================== تحليل النتائج ====================
      if (foundSessions.isEmpty) {
        setState(() {
          _hasSessions = false;
          _message =
              '📅 لا توجد حصص تدريبية في يوم ${_formatDate(_selectedDate)}';
          _records = [];
          _students = [];
          _selectedHallId = null;
          _selectedGroupId = null;
          _selectedSessionId = null;
          _isLoadingData = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _hasSessions = true;
        _isFieldsDisabled = true;
      });

      // ==================== اختيار الحصة المناسبة ====================
      SessionWithDetails? bestSession;

      // إعطاء الأولوية للحصة الاستثنائية
      final extraSessions = foundSessions.where((s) => s.isExtra).toList();
      if (extraSessions.isNotEmpty) {
        bestSession = extraSessions.first;
        print('✅ تم اختيار حصة استثنائية تلقائياً');
      } else {
        // اختيار الحصة العادية الأقرب
        final now = DateTime.now();
        final currentTime = now.hour * 60 + now.minute;

        if (_selectedDate.year == now.year &&
            _selectedDate.month == now.month &&
            _selectedDate.day == now.day) {
          // اليوم الحالي: اختر الأقرب
          int minDiff = 999999;
          for (var session in foundSessions) {
            final sessionStartMinutes = session.session.startTime.hour * 60 +
                session.session.startTime.minute;
            final diff = (sessionStartMinutes - currentTime).abs();
            if (diff < minDiff) {
              minDiff = diff;
              bestSession = session;
            }
          }
        } else {
          // تاريخ مختلف: اختر الأول
          bestSession = foundSessions.first;
        }
      }

      if (bestSession != null) {
        setState(() {
          _selectedHallId = bestSession!.hall.id;
          _selectedGroupId = bestSession!.group.id;
          _selectedSessionId = bestSession!.session.id;
          _autoSelected = true;
          _isExtraSession = bestSession.isExtra;

          if (bestSession.isExtra) {
            _extraSession = ExtraSessionModel(
              id: bestSession.extraId,
              date: DateTime(
                  _selectedDate.year, _selectedDate.month, _selectedDate.day),
              hallId: bestSession.hall.id!,
              groupId: bestSession.group.id!,
              startTime: bestSession.session.startTime,
              endTime: bestSession.session.endTime,
              reason: bestSession.extraReason,
              createdAt: DateTime.now(),
            );
          }
        });

        // تحميل البيانات
        await _loadGroups(bestSession.hall.id!);
        await _loadSessionsForGroup(bestSession.group.id!);
        await _loadAttendance(bestSession.group.id!);

        // بناء رسالة الحالة
        String statusText = '';
        if (foundSessions.length > 1) {
          statusText = ' (${foundSessions.length} حصص في هذا اليوم)';
        }
        if (bestSession.isExtra) {
          statusText += ' 📝 حصة استثنائية';
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
              '✅ ${bestSession!.hall.name} → ${bestSession!.group.name} → ${bestSession!.session.dayName ?? ""} ${_formatTime(bestSession!.session.startTime)} - ${_formatTime(bestSession!.session.endTime)}$statusText';
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

  // ==================== إنشاء حصة استثنائية ====================
  Future<void> _createExtraSession() async {
    if (_halls.isEmpty) {
      CustomSnackbar.showError(
        context,
        'لا توجد قاعات. الرجاء إضافة قاعة في الإعدادات.',
      );
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

                    // اختيار القاعة
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

                    // اختيار الفوج
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

                    // وقت البداية
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

                    // وقت النهاية
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

                    // ✅ سبب الحصة الاستثنائية (اختياري)
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
                      context,
                      'الرجاء اختيار القاعة والفوج',
                    );
                    return;
                  }

                  // حفظ الحصة الاستثنائية في قاعدة البيانات
                  try {
                    final db = await getIt<AppDatabase>().database;
                    final extraSession = ExtraSessionModel(
                      date: DateTime(_selectedDate.year, _selectedDate.month,
                          _selectedDate.day), // ✅ توحيد التاريخ

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
                      context,
                      'تم إنشاء الحصة الاستثنائية بنجاح',
                    );
                  } catch (e) {
                    print('❌ خطأ في حفظ الحصة الاستثنائية: $e');
                    CustomSnackbar.showError(
                      context,
                      'فشل حفظ الحصة الاستثنائية',
                    );
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
      // إعادة تحميل البيانات لعرض الحصة الاستثنائية
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

        // إعادة تحميل البيانات
        await _loadAllData();
        CustomSnackbar.showSuccess(context, 'تم حذف الحصة الاستثنائية بنجاح');
      } catch (e) {
        print('❌ خطأ في حذف الحصة الاستثنائية: $e');
        CustomSnackbar.showError(context, 'فشل حذف الحصة الاستثنائية');
      }
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
      _sessions = await _groupRepo.getSessionsByGroup(groupId);
      setState(() {});
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
        date: DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day),
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
              date: DateTime(
                  _selectedDate.year, _selectedDate.month, _selectedDate.day),
            );
          } else {
            await _attendanceRepo.markAbsent(
              studentId: record.studentId,
              groupId: _selectedGroupId!,
              date: DateTime(
                  _selectedDate.year, _selectedDate.month, _selectedDate.day),
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
          builder: (_) => const QRScannerScreen(
            title: 'مسح حضور الطلاب',
            continuousMode: true,
          ),
        ),
      );

      if (result != null && mounted) {
        if (result is List<String>) {
          int successCount = 0;
          int errorCount = 0;

          for (var code in result) {
            final studentId = int.tryParse(code);
            if (studentId != null) {
              final index = _records.indexWhere(
                (r) => r.studentId == studentId,
              );
              if (index != -1) {
                if (!_records[index].isPresent) {
                  _toggleAttendance(index, isPresent: true);
                  successCount++;
                }
              } else {
                errorCount++;
              }
            }
          }

          String message = '';
          if (successCount > 0) message += '✅ تم تسجيل حضور $successCount طالب';
          if (errorCount > 0) message += ' ❌ $errorCount طالب غير موجود';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في مسح QR Code: $e');
    }
  }

  // ==================== نافذة سبب الغياب ====================
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

  // ==================== إحصائيات الحضور ====================
  int get _presentCount => _records.where((r) => r.isPresent).length;
  int get _absentCount => _records.where((r) => !r.isPresent).length;
  double get _attendancePercentage =>
      _records.isEmpty ? 0 : (_presentCount / _records.length) * 100;

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
                  // ==================== اختيار التاريخ ====================
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '📅 تاريخ الحصة',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(_selectedDate)),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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

                  // ==================== أزرار الحصة الاستثنائية ====================
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

// ✅ زر حذف الحصة الاستثنائية (يظهر عند وجود حصة استثنائية)
                  if (_isExtraSession && _extraSession != null)
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

                  // ==================== إذا كان هناك حصص ====================
                  if (_hasSessions) ...[
                    // اختيار القاعة (معطل)
                    const Text(
                      'القاعة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedHallId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

                    // اختيار الفوج (معطل)
                    const Text(
                      'الفوج',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedGroupId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

// اختيار الحصة (معطل إذا كانت هناك حصة مسجلة)
                    const Text('الحصة التدريبية',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedSessionId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.schedule),
                        hintText:
                            _getSessionDisplayText(), // ✅ استخدام دالة جديدة
                      ),
                      isExpanded: true,
                      items: _sessions.map((session) {
                        return DropdownMenuItem(
                          value: session.id,
                          child: Text(_getSessionTime(session)),
                        );
                      }).toList(),
                      onChanged: _isFieldsDisabled ? null : _onSessionChanged,
                    ),

                    if (_isFieldsDisabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🔒 تم تعطيل الحقول تلقائياً لوجود حصة مسجلة',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
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

                        // أزرار التحكم السريع
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
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

// ==================== الحصول على نص عرض الحصة ====================
  String _getSessionDisplayText() {
    // إذا كانت الحقول معطلة (يوجد حصة مسجلة)
    if (_isFieldsDisabled) {
      // إذا كانت حصة استثنائية
      if (_isExtraSession && _extraSession != null) {
        final session = _extraSession!;
        final dayName = _getDayName(session.date.weekday);
        return '$dayName ${_formatTime(session.startTime)} - ${_formatTime(session.endTime)}';
      }

      // إذا كانت حصة عادية
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

// ==================== الحصول على اسم اليوم ====================
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
    // weekday في DateTime: 1=الإثنين, 7=الأحد
    final index = weekday == 7 ? 0 : weekday;
    return days[index];
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

  // ==================== دوال لتغيير الحقول يدوياً (للحصة الاستثنائية) ====================
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
    await _loadSessionsForGroup(groupId);
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
