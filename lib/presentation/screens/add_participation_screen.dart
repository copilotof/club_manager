// lib/presentation/screens/add_participation_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/competition_model.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/competition_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

// استيراد نماذج الإعدادات
import 'settings_screen.dart';

class AddParticipationScreen extends StatefulWidget {
  final int competitionId;
  final CompetitionModel competition;

  const AddParticipationScreen({
    super.key,
    required this.competitionId,
    required this.competition,
  });

  @override
  State<AddParticipationScreen> createState() => _AddParticipationScreenState();
}

class _AddParticipationScreenState extends State<AddParticipationScreen> {
  late StudentRepository _studentRepo;
  late CompetitionRepository _competitionRepo;

  List<StudentModel> _students = [];
  List<StudentModel> _availableStudents = [];
  List<ParticipationItem> _participations = [];

  // للإعدادات الرياضية
  List<SpecialtyItem> _specialties = [];
  int? _selectedSpecialtyId;

  // للمشاركة الجديدة
  StudentModel? _selectedStudent;
  String _selectedAgeCategory = '';
  final _weightController = TextEditingController();
  String _selectedResult = 'participation';
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _competitionRepo = CompetitionRepository(localDb: getIt());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تحميل الطلاب
      _students = await _studentRepo.getAllStudents();

      // تحميل الاختصاصات من الإعدادات
      await _loadSpecialties();

      // تحديد أول اختصاص تلقائياً
      if (_specialties.isNotEmpty && _selectedSpecialtyId == null) {
        _selectedSpecialtyId = _specialties.first.id;
      }

      // تحميل المشاركات الحالية
      await _loadExistingParticipations();

      // تحديث قائمة الطلاب المتاحين (غير المشاركين في هذا الاختصاص)
      _updateAvailableStudents();
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSpecialties() async {
    final prefs = await SharedPreferences.getInstance();
    final specialtiesJson = prefs.getString('sports_specialties');

    if (specialtiesJson != null && specialtiesJson.isNotEmpty) {
      final List<dynamic> data = jsonDecode(specialtiesJson);
      _specialties = data.map((s) => SpecialtyItem.fromJson(s)).toList();
    }
  }

  Future<void> _loadExistingParticipations() async {
    // TODO: جلب المشاركات الحالية من قاعدة البيانات
    _participations = [];
  }

  void _updateAvailableStudents() {
    // الحصول على IDs الطلاب المشاركين بالفعل في هذا الاختصاص
    final participatedIds = _participations
        .where((p) => p.specialtyId == _selectedSpecialtyId)
        .map((p) => p.studentId)
        .toSet();

    // تصفية الطلاب غير المشاركين
    _availableStudents = _students
        .where((s) => !participatedIds.contains(s.id))
        .toList();
  }

  // حساب الفئة العمرية تلقائياً حسب عمر الطالب
  String _calculateAgeCategory(StudentModel student) {
    final age = student.age;

    // البحث عن الفئة العمرية المناسبة في الاختصاص المختار
    final specialty = _specialties.firstWhere(
      (s) => s.id == _selectedSpecialtyId,
      orElse: () => SpecialtyItem(id: 0, name: '', ageCategories: []),
    );

    for (var category in specialty.ageCategories) {
      if (age >= category.minAge && age <= category.maxAge) {
        return category.name;
      }
    }

    return 'غير محدد';
  }

  void _onStudentSelected(StudentModel? student) {
    setState(() {
      _selectedStudent = student;
      if (student != null) {
        _selectedAgeCategory = _calculateAgeCategory(student);
      } else {
        _selectedAgeCategory = '';
      }
    });
  }

  void _onSpecialtyChanged(int? specialtyId) {
    setState(() {
      _selectedSpecialtyId = specialtyId;
      _selectedStudent = null;
      _selectedAgeCategory = '';
      _updateAvailableStudents();
    });
  }

  void _addParticipation() async {
    if (_selectedSpecialtyId == null) {
      CustomSnackbar.showError(context, 'الرجاء اختيار الاختصاص');
      return;
    }

    if (_selectedStudent == null) {
      CustomSnackbar.showError(context, 'الرجاء اختيار طالب');
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      CustomSnackbar.showError(context, 'الرجاء إدخال وزن صحيح');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // TODO: حفظ المشاركة في قاعدة البيانات
    await Future.delayed(const Duration(milliseconds: 500));

    // إضافة المشاركة إلى القائمة المحلية
    _participations.add(
      ParticipationItem(
        studentId: _selectedStudent!.id!,
        studentName: _selectedStudent!.fullName,
        specialtyId: _selectedSpecialtyId!,
        ageCategory: _selectedAgeCategory,
        weight: weight,
        result: _selectedResult,
        notes: _notesController.text,
      ),
    );

    // تحديث القوائم
    _updateAvailableStudents();

    // إعادة تعيين الحقول
    setState(() {
      _selectedStudent = null;
      _selectedAgeCategory = '';
      _weightController.clear();
      _notesController.clear();
      _isSaving = false;
    });

    CustomSnackbar.showSuccess(context, 'تم إضافة المشارك بنجاح');
  }

  void _removeParticipation(int studentId) {
    setState(() {
      _participations.removeWhere((p) => p.studentId == studentId);
      _updateAvailableStudents();
    });
    CustomSnackbar.showSuccess(context, 'تم حذف المشارك');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المشاركين')),
      body: Column(
        children: [
          // نموذج إضافة مشارك جديد
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إضافة مشارك جديد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 1. اختيار الاختصاص (تلقائياً أول اختصاص)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'الاختصاص',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports_martial_arts),
                  ),
                  value: _selectedSpecialtyId,
                  items: _specialties.map((specialty) {
                    return DropdownMenuItem(
                      value: specialty.id,
                      child: Text(specialty.name),
                    );
                  }).toList(),
                  onChanged: (value) => _onSpecialtyChanged(value),
                ),

                const SizedBox(height: 12),

                // 2. اختيار الطالب (لا يتكرر في نفس الاختصاص)
                DropdownButtonFormField<StudentModel>(
                  decoration: const InputDecoration(
                    labelText: 'الطالب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: _selectedStudent,
                  isExpanded: true,
                  hint: const Text('-- اختر طالب --'),
                  items: _availableStudents.map((student) {
                    return DropdownMenuItem(
                      value: student,
                      child: Text(student.fullName),
                    );
                  }).toList(),
                  onChanged: _onStudentSelected,
                ),

                const SizedBox(height: 12),

                // 3. الفئة العمرية (تكتب تلقائياً)
                TextFormField(
                  controller: TextEditingController(text: _selectedAgeCategory),
                  decoration: const InputDecoration(
                    labelText: 'الفئة العمرية',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  readOnly: true,
                ),

                const SizedBox(height: 12),

                // 4. فئة الوزن (يكتب يدوياً)
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'فئة الوزن (كغ)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 12),

                // 5. النتيجة
                const Text(
                  'النتيجة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'gold', label: Text('🥇 ذهبية')),
                    ButtonSegment(value: 'silver', label: Text('🥈 فضية')),
                    ButtonSegment(value: 'bronze', label: Text('🥉 برونزية')),
                    ButtonSegment(
                      value: 'participation',
                      label: Text('📋 مشاركة'),
                    ),
                  ],
                  selected: {_selectedResult},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _selectedResult = selection.first;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // 6. ملاحظات
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 12),

                // زر الإضافة
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _addParticipation,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مشارك'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // قائمة المشاركين الحاليين
          Expanded(
            child: _participations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد مشاركون',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _participations.length,
                    itemBuilder: (context, index) {
                      final p = _participations[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getResultColor(
                              p.result,
                            ).withOpacity(0.1),
                            child: Text(
                              p.result == 'gold'
                                  ? '🥇'
                                  : p.result == 'silver'
                                  ? '🥈'
                                  : p.result == 'bronze'
                                  ? '🥉'
                                  : '📋',
                            ),
                          ),
                          title: Text(p.studentName),
                          subtitle: Text(
                            '${p.ageCategory} - ${p.weight.toStringAsFixed(0)} كغ',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeParticipation(p.studentId),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getResultColor(String result) {
    switch (result) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      case 'bronze':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}

// نموذج بسيط للمشاركة
class ParticipationItem {
  final int studentId;
  final String studentName;
  final int specialtyId;
  final String ageCategory;
  final double weight;
  final String result;
  final String notes;

  ParticipationItem({
    required this.studentId,
    required this.studentName,
    required this.specialtyId,
    required this.ageCategory,
    required this.weight,
    required this.result,
    required this.notes,
  });
}
