// lib/presentation/screens/coach_notes_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/models/coach_note_model.dart';
import '../../core/widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';
import '../../injection/dependency_injection.dart';

class CoachNotesScreen extends StatefulWidget {
  final int sessionId;
  final DateTime sessionDate;

  const CoachNotesScreen({
    super.key,
    required this.sessionId,
    required this.sessionDate,
  });

  @override
  State<CoachNotesScreen> createState() => _CoachNotesScreenState();
}

class _CoachNotesScreenState extends State<CoachNotesScreen> {
  final List<NotePart> _parts = [];
  final _titleController = TextEditingController();
  final _generalNotesController = TextEditingController();
  bool _isSaving = false;

  int _totalMinutes = 90;
  int _usedMinutes = 0;

  // قائمة الأجزاء المقترحة
  List<String> _suggestedParts = [];

  @override
  void initState() {
    super.initState();
    _loadSessionDuration();
    _addDefaultParts();
    _loadSessionParts();
  }

// ==================== جلب أجزاء الحصة من الإعدادات ====================
  Future<void> _loadSessionParts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final partsJson = prefs.getStringList('session_parts');

      if (partsJson != null && partsJson.isNotEmpty) {
        // ✅ تحديث قائمة الأجزاء المقترحة من الإعدادات
        setState(() {
          _suggestedParts = List.from(partsJson);
        });
        print('📋 تم جلب أجزاء الحصة من الإعدادات: $_suggestedParts');
      } else {
        // ✅ قيم افتراضية إذا لم توجد في الإعدادات
        _suggestedParts = [
          'تسخينات',
          'جري',
          'تمارين لياقة',
          'تقنيات',
          'منازلات',
          'تبريد'
        ];
        print('📋 استخدام القيم الافتراضية لأجزاء الحصة');
      }
    } catch (e) {
      print('⚠️ خطأ في جلب أجزاء الحصة: $e');
      _suggestedParts = [
        'تسخينات',
        'جري',
        'تمارين لياقة',
        'تقنيات',
        'منازلات',
        'تبريد'
      ];
    }
  }

// ==================== جلب وقت الحصة من قاعدة البيانات (تشمل الاستثنائية) ====================
  Future<void> _loadSessionDuration() async {
    try {
      final db = await getIt<AppDatabase>().database;

      // ✅ 1. البحث في جدول sessions (الحصص العادية)
      var result = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [widget.sessionId],
      );

      // ✅ 2. إذا لم يتم العثور، البحث في جدول extra_sessions (الحصص الاستثنائية)
      if (result.isEmpty) {
        result = await db.query(
          'extra_sessions',
          where: 'id = ?',
          whereArgs: [widget.sessionId],
        );
      }

      if (result.isNotEmpty) {
        final startTime = result.first['start_time'] as String;
        final endTime = result.first['end_time'] as String;

        final startParts = startTime.split(':');
        final endParts = endTime.split(':');

        final startHour = int.parse(startParts[0]);
        final startMinute = int.parse(startParts[1]);
        final endHour = int.parse(endParts[0]);
        final endMinute = int.parse(endParts[1]);

        _totalMinutes =
            (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
        print('⏰ مدة الحصة (استثنائية): $_totalMinutes دقيقة');
      } else {
        // ✅ 3. قيمة افتراضية إذا لم يتم العثور على الحصة
        _totalMinutes = 90;
        print(
            '⚠️ لم يتم العثور على الحصة، استخدام القيمة الافتراضية: 90 دقيقة');
      }
    } catch (e) {
      print('⚠️ خطأ في جلب مدة الحصة: $e');
      _totalMinutes = 90;
    }
    setState(() {});
  }

  // ==================== إضافة أجزاء افتراضية ====================
  void _addDefaultParts() {
    // توزيع افتراضي للحصة
    final int remaining = _totalMinutes;
    _parts.addAll([]);
    _updateUsedMinutes();
  }

  // ==================== تحديث مجموع الدقائق ====================
  void _updateUsedMinutes() {
    _usedMinutes = _parts.fold(0, (sum, p) => sum + p.minutes);
  }

  // ==================== إضافة جزء جديد ====================
  void _addPart(String name) {
    setState(() {
      _parts.add(NotePart(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        minutes: 0,
      ));
      _updateUsedMinutes();
    });
  }

  // ==================== حذف جزء ====================
  void _removePart(int id) {
    setState(() {
      _parts.removeWhere((p) => p.id == id);
      _updateUsedMinutes();
    });
  }

  // ==================== تحديث الدقائق ====================
  void _updateMinutes(int id, int value) {
    setState(() {
      final index = _parts.indexWhere((p) => p.id == id);
      if (index != -1) {
        _parts[index] = NotePart(
          id: _parts[index].id,
          name: _parts[index].name,
          minutes: value.clamp(0, _totalMinutes),
          description: _parts[index].description,
        );
        _updateUsedMinutes();
      }
    });
  }

  // ==================== التحقق من صحة المجموع ====================
  bool get _isValidTotal {
    return _usedMinutes == _totalMinutes;
  }

  int get _remainingMinutes {
    return _totalMinutes - _usedMinutes;
  }

  // ==================== حفظ الملاحظات ====================
  Future<void> _saveNotes() async {
    if (_titleController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, 'الرجاء إدخال عنوان للملاحظات');
      return;
    }

    if (_parts.isEmpty) {
      CustomSnackbar.showError(context, 'الرجاء إضافة أجزاء للحصة');
      return;
    }

    if (!_isValidTotal) {
      CustomSnackbar.showError(
        context,
        'مجموع الدقائق يجب أن يساوي $_totalMinutes دقيقة (الحالي: $_usedMinutes دقيقة)',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await getIt<AppDatabase>().database;

      // تحويل الأجزاء إلى JSON
      final partsJson = jsonEncode(_parts
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'minutes': p.minutes,
                'description': p.description,
              })
          .toList());

      final note = {
        'session_id': widget.sessionId,
        'session_date': widget.sessionDate.toIso8601String(),
        'title': _titleController.text.trim(),
        'parts': partsJson,
        'general_notes': _generalNotesController.text.isEmpty
            ? null
            : _generalNotesController.text,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // التحقق من وجود ملاحظات سابقة
      final existing = await db.query(
        'coach_notes',
        where: 'session_id = ?',
        whereArgs: [widget.sessionId],
      );

      if (existing.isNotEmpty) {
        await db.update('coach_notes', note,
            where: 'session_id = ?', whereArgs: [widget.sessionId]);
      } else {
        await db.insert('coach_notes', note);
      }

      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'تم حفظ الملاحظات بنجاح');
      Navigator.pop(context, true);
    } catch (e) {
      print('❌ خطأ في حفظ الملاحظات: $e');
      CustomSnackbar.showError(context, 'فشل حفظ الملاحظات: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

// ==================== عرض جزء مع شريط تقدم تفاعلي ====================
  Widget _buildPartItem(NotePart part) {
    final remaining = _totalMinutes - _usedMinutes + part.minutes;
    final progressValue = _totalMinutes > 0 ? part.minutes / _totalMinutes : 0;
    final isOverflow = _usedMinutes > _totalMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverflow
            ? BorderSide(color: Colors.red.shade300, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس الجزء
            Row(
              children: [
                // رقم الجزء
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_parts.indexOf(part) + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    part.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // عرض الدقائق
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${part.minutes} دقيقة',
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => _removePart(part.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ شريط التقدم التفاعلي
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapDown: (details) {
                      // الحصول على عرض الشريط وتحديث القيمة
                      _updateProgressFromTap(part.id, details);
                    },
                    onPanUpdate: (details) {
                      // تحديث القيمة عند السحب
                      _updateProgressFromTap(part.id, details);
                    },
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            // الخلفية
                            Positioned.fill(
                              child: Container(
                                color: Colors.grey[200],
                              ),
                            ),
                            // شريط التقدم
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width *
                                  0.7 *
                                  progressValue.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      isOverflow
                                          ? Colors.red
                                          : const Color(0xFFE53935),
                                      isOverflow
                                          ? Colors.red.shade300
                                          : Colors.green,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${(progressValue * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // علامات التحديد
                            ...List.generate(10, (index) {
                              final position = (index + 1) * 0.1;
                              return Positioned(
                                left: MediaQuery.of(context).size.width *
                                    0.7 *
                                    position,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // زر زيادة ونقصان
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () {
                        final newValue = part.minutes + 1;
                        _updateMinutes(
                            part.id, newValue.clamp(0, _totalMinutes));
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: () {
                        final newValue = part.minutes - 1;
                        _updateMinutes(
                            part.id, newValue.clamp(0, _totalMinutes));
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),

            // ✅ معلومات إضافية
            const SizedBox(height: 8),
            Row(
              children: [
                // حقل إدخال الدقائق يدوياً
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'عدد الدقائق',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      suffixText: 'دقيقة',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: part.minutes.toString()),
                    onChanged: (value) {
                      final newMinutes = int.tryParse(value) ?? 0;
                      _updateMinutes(
                          part.id, newMinutes.clamp(0, _totalMinutes));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // المتبقي
                /*        Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remaining >= 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: remaining >= 0
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                      child: Text(
                    'المتبقي: ${remaining >= 0 ? remaining : 0} دقيقة',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ), */
              ],
            ),

            // حالة المجموع
            if (!_isValidTotal)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _usedMinutes > _totalMinutes
                      ? '⚠️ تجاوزت المدة المحددة بـ ${_usedMinutes - _totalMinutes} دقيقة'
                      : '⚠️ متبقي ${_totalMinutes - _usedMinutes} دقيقة لتوزيعها',
                  style: TextStyle(
                    fontSize: 11,
                    color: _usedMinutes > _totalMinutes
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// ==================== تحديث التقدم من النقر/السحب ====================
  void _updateProgressFromTap(int id, dynamic details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);
    final double width = box.size.width;
    final double progress = (localOffset.dx / width).clamp(0.0, 1.0);
    final int newMinutes = (progress * _totalMinutes).round();
    _updateMinutes(id, newMinutes.clamp(0, _totalMinutes));
  }

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('yyyy/MM/dd', 'en_US').format(widget.sessionDate);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ملاحظات المدرب'),
            Text(
              '$formattedDate',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveNotes,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان الملاحظات
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان الملاحظات *',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
                hintText: 'مثال: خطة تدريب اليوم',
              ),
            ),

            const SizedBox(height: 16),

            // ملخص الوقت
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isValidTotal
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isValidTotal ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'مجموع الدقائق:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_usedMinutes / $_totalMinutes دقيقة',
                    style: TextStyle(
                      color: _isValidTotal ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            if (!_isValidTotal) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ المتبقي: ${_remainingMinutes} دقيقة',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // قائمة الأجزاء
            const Text(
              'أجزاء الحصة التدريبية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ..._parts.map((part) => _buildPartItem(part)),

            const SizedBox(height: 16),

            // إضافة جزء جديد
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._suggestedParts.map((name) {
                  final exists = _parts.any((p) => p.name == name);
                  return ActionChip(
                    label: Text(name),
                    onPressed: false ? null : () => _addPart(name),
                    backgroundColor:
                        false ? Colors.grey.shade300 : Colors.blue.shade50,
                    avatar: exists
                        ? const Icon(Icons.check, size: 16, color: Colors.green)
                        : null,
                  );
                }),
              ],
            ),

            const SizedBox(height: 24),

            // ملاحظات عامة
            TextFormField(
              controller: _generalNotesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات عامة (اختياري)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حفظ الملاحظات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
