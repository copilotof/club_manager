// lib/presentation/screens/add_competition_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/competition_model.dart';
import '../../data/repositories/competition_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

// استيراد نماذج الإعدادات
import 'settings_screen.dart';

class AddCompetitionScreen extends StatefulWidget {
  final CompetitionModel? competition;
  const AddCompetitionScreen({super.key, this.competition});

  @override
  State<AddCompetitionScreen> createState() => _AddCompetitionScreenState();
}

class _AddCompetitionScreenState extends State<AddCompetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'national';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));

  // الاختصاصات والفئات العمرية من الإعدادات
  List<SpecialtyItem> _specialties = [];
  List<int> _selectedSpecialtyIds = [];
  List<String> _selectedAgeCategories = [];

  // تخزين الفئات العمرية لكل اختصاص على حدة
  Map<int, List<String>> _selectedAgeCategoriesBySpecialty = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecialtiesFromSettings();
    if (widget.competition != null) {
      _fillForm();
    }
  }

  Future<void> _loadSpecialtiesFromSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final specialtiesJson = prefs.getString('sports_specialties');

      if (specialtiesJson != null && specialtiesJson.isNotEmpty) {
        final List<dynamic> data = jsonDecode(specialtiesJson);
        _specialties = data.map((s) => SpecialtyItem.fromJson(s)).toList();
      } else {
        // بيانات افتراضية إذا لم توجد
        _specialties = [
          SpecialtyItem(
            id: 1,
            name: 'واكو حلبة',
            ageCategories: [
              AgeCategoryItem(name: 'أكابر', minAge: 19, maxAge: 40),
              AgeCategoryItem(name: 'أواسط', minAge: 17, maxAge: 18),
              AgeCategoryItem(name: 'أشبال', minAge: 13, maxAge: 15),
              AgeCategoryItem(name: 'أصاغر', minAge: 10, maxAge: 12),
            ],
          ),
          SpecialtyItem(
            id: 2,
            name: 'واكو بساط',
            ageCategories: [
              AgeCategoryItem(name: 'أكابر', minAge: 19, maxAge: 40),
              AgeCategoryItem(name: 'أواسط', minAge: 17, maxAge: 18),
              AgeCategoryItem(name: 'أشبال', minAge: 13, maxAge: 15),
            ],
          ),
        ];
      }
    } catch (e) {
      print('خطأ في تحميل الاختصاصات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fillForm() {
    final c = widget.competition!;
    _nameController.text = c.name;
    _type = c.type;
    _startDate = c.startDate;
    _endDate = c.endDate;
    _locationController.text = c.location;
    _selectedSpecialtyIds = List.from(c.specialtyIds);
    _selectedAgeCategories = List.from(c.ageCategories);
    _notesController.text = c.notes ?? '';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'DZ'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
      locale: const Locale('ar', 'DZ'),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveCompetition() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSpecialtyIds.isEmpty) {
        CustomSnackbar.showError(
          context,
          'الرجاء اختيار اختصاص واحد على الأقل',
        );
        return;
      }
      if (_selectedAgeCategories.isEmpty) {
        CustomSnackbar.showError(
          context,
          'الرجاء اختيار فئة عمرية واحدة على الأقل',
        );
        return;
      }

      final competition = CompetitionModel(
        id: widget.competition?.id,
        name: _nameController.text,
        type: _type,
        startDate: _startDate,
        endDate: _endDate,
        location: _locationController.text,
        specialtyIds: _selectedSpecialtyIds,
        ageCategories: _selectedAgeCategories,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final repo = CompetitionRepository(localDb: getIt());

      if (widget.competition == null) {
        await repo.addCompetition(competition);
        CustomSnackbar.showSuccess(context, 'تم إضافة البطولة بنجاح');
      } else {
        await repo.updateCompetition(competition);
        CustomSnackbar.showSuccess(context, 'تم تحديث البطولة بنجاح');
      }

      Navigator.pop(context, true);
    }

    // جمع كل الفئات العمرية المختارة
    List<String> allSelectedCategories = [];
    for (var categories in _selectedAgeCategoriesBySpecialty.values) {
      allSelectedCategories.addAll(categories);
    }
  }

  // الحصول على الفئات العمرية للاختصاصات المختارة فقط
  List<AgeCategoryItem> _getAgeCategoriesForSelectedSpecialties() {
    Set<AgeCategoryItem> allCategories = {};

    // تصفية الاختصاصات المختارة فقط
    for (var specialty in _specialties) {
      if (_selectedSpecialtyIds.contains(specialty.id)) {
        allCategories.addAll(specialty.ageCategories);
      }
    }

    return allCategories.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.competition == null ? 'إضافة بطولة جديدة' : 'تعديل بطولة',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // اسم البطولة
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم البطولة',
                prefixIcon: Icon(Icons.emoji_events),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'اسم البطولة مطلوب' : null,
            ),

            const SizedBox(height: 16),

            // نوع البطولة
            const Text(
              'نوع البطولة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'regional',
                  label: Text('ولائية'),
                  icon: Icon(Icons.location_city),
                ),
                ButtonSegment(
                  value: 'national',
                  label: Text('وطنية'),
                  icon: Icon(Icons.flag),
                ),
                ButtonSegment(
                  value: 'international',
                  label: Text('دولية'),
                  icon: Icon(Icons.public),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _type = selection.first;
                });
              },
            ),

            const SizedBox(height: 16),

            // تاريخ البطولة
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ البدء',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ النهاية',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // المكان
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'المكان',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // الاختصاصات المعنية

            /*             const Text(
              'الاختصاصات المعنية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _specialties.map((specialty) {
                final isSelected = _selectedSpecialtyIds.contains(specialty.id);
                return FilterChip(
                  label: Text(specialty.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSpecialtyIds.add(specialty.id);
                      } else {
                        _selectedSpecialtyIds.remove(specialty.id);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFE53935).withOpacity(0.2),
                );
              }).toList(),
            ),

 */
            // الاختصاصات المعنية
            const Text(
              'الاختصاصات المعنية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _specialties.map((specialty) {
                final isSelected = _selectedSpecialtyIds.contains(specialty.id);
                return FilterChip(
                  label: Text(specialty.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSpecialtyIds.add(specialty.id);
                        // تهيئة قائمة فارغة للفئات العمرية لهذا الاختصاص
                        _selectedAgeCategoriesBySpecialty[specialty.id] = [];
                      } else {
                        _selectedSpecialtyIds.remove(specialty.id);
                        _selectedAgeCategoriesBySpecialty.remove(specialty.id);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFE53935).withOpacity(0.2),
                );
              }).toList(),
            ),

            // الفئات العمرية لكل اختصاص على حدة
            if (_selectedSpecialtyIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'الفئات العمرية المشاركة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._selectedSpecialtyIds.map((specialtyId) {
                final specialty = _specialties.firstWhere(
                  (s) => s.id == specialtyId,
                );
                final selectedCategories =
                    _selectedAgeCategoriesBySpecialty[specialtyId] ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختصاص: ${specialty.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: specialty.ageCategories.map((category) {
                        final isSelected = selectedCategories.contains(
                          category.name,
                        );
                        return FilterChip(
                          label: Text(
                            '${category.name} (${category.minAge}-${category.maxAge} سنة)',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAgeCategoriesBySpecialty[specialtyId]!
                                    .add(category.name);
                              } else {
                                _selectedAgeCategoriesBySpecialty[specialtyId]!
                                    .remove(category.name);
                              }
                            });
                          },
                          selectedColor: const Color(
                            0xFFE53935,
                          ).withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ],
            // الفئات العمرية المشاركة (تظهر فقط بعد اختيار اختصاص)
            if (_selectedSpecialtyIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'الفئات العمرية المشاركة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _getAgeCategoriesForSelectedSpecialties().map((
                  category,
                ) {
                  final isSelected = _selectedAgeCategories.contains(
                    category.name,
                  );
                  return FilterChip(
                    label: Text(
                      '${category.name} (${category.minAge}-${category.maxAge} سنة)',
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAgeCategories.add(category.name);
                        } else {
                          _selectedAgeCategories.remove(category.name);
                        }
                      });
                    },
                    selectedColor: const Color(0xFFE53935).withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // ملاحظات
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // زر الحفظ
            ElevatedButton(
              onPressed: _saveCompetition,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                widget.competition == null ? 'إضافة البطولة' : 'تحديث البطولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
