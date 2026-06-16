// lib/presentation/screens/add_edit_student_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../data/models/group_model.dart';
import '../../data/models/hall_model.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/hall_repository.dart';
import '../bloc/student/student_bloc.dart';
import '../bloc/student/events/student_event.dart';
import '../bloc/student/states/student_state.dart';
import '../../core/utils/responsive_utils.dart';
import '../../injection/dependency_injection.dart';

import '../../data/models/hall_model.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/hall_repository.dart';
import '../../data/repositories/group_repository.dart';

class AddEditStudentScreen extends StatefulWidget {
  final StudentModel? student;
  const AddEditStudentScreen({super.key, this.student});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen>
    with SingleTickerProviderStateMixin {
  late StudentBloc _studentBloc;
  late TabController _tabController;

  // متغير لمنع الضغط المتكرر أثناء الحفظ
  bool _isSaving = false;

  // Controllers للمعلومات الشخصية
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  String _gender = 'ذكر';
  final _parentPhoneController = TextEditingController();

  // Controllers للمعلومات الدراسية
  final _semester1Controller = TextEditingController();
  final _semester2Controller = TextEditingController();
  final _semester3Controller = TextEditingController();
  final _academicNotesController = TextEditingController();

  // Controllers للمعلومات الصحية
  bool _hasChronicDisease = false;
  final _diseaseNameController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _medicalInstructionsController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // ==================== للقاعات والأفواج ====================
  // المتغيرات
  List<HallModel> _halls = [];
  List<GroupModel> _groups = [];
  int? _selectedHallId;
  int? _selectedGroupId;
  bool _isLoadingHalls = true;
  bool _isLoadingGroups = false;

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _studentBloc = StudentBloc(getIt());
    _tabController = TabController(length: 3, vsync: this);

    // تحميل القاعات (والأفواج تلقائياً)
    _loadHalls();

    // إذا كان تعديل، املأ البيانات بعد تحميل القاعات
    if (widget.student != null) {
      _fillFormWithStudentData();
    }
  }

  void _fillFormWithStudentData() async {
    final s = widget.student!;
    _firstNameController.text = s.firstName;
    _lastNameController.text = s.lastName;
    _selectedDate = s.birthDate;
    _birthDateController.text = _formatDate(s.birthDate);
    _gender = s.gender;
    _parentPhoneController.text = s.parentPhone ?? '';

    // ✅ تعيين القاعة إذا كانت موجودة
    if (s.hallId != null) {
      setState(() {
        _selectedHallId = s.hallId;
      });
      // تحميل الأفواج لهذه القاعة أولاً
      await _loadGroups(s.hallId!);

      // ✅ بعد تحميل الأفواج، قم بتعيين الفوج
      if (s.groupId != null && _groups.any((g) => g.id == s.groupId)) {
        setState(() {
          _selectedGroupId = s.groupId;
        });
      }
    }

    // باقي الحقول...
    _semester1Controller.text = s.semester1Grade?.toString() ?? '';
    _semester2Controller.text = s.semester2Grade?.toString() ?? '';
    _semester3Controller.text = s.semester3Grade?.toString() ?? '';
    _academicNotesController.text = s.academicNotes ?? '';

    _hasChronicDisease = s.hasChronicDisease;
    _diseaseNameController.text = s.diseaseName ?? '';
    _medicationsController.text = s.medications ?? '';
    _medicalInstructionsController.text = s.medicalInstructions ?? '';
    _doctorNameController.text = s.doctorName ?? '';
    _emergencyPhoneController.text = s.emergencyPhone ?? '';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ✅ دالة اختيار التاريخ المحسنة (تقبل تواريخ من 1950)
  Future<void> _selectDate(BuildContext context) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selectedDate ?? DateTime(2000, 1, 1),
            maximumDate: DateTime.now(),
            minimumDate: DateTime(1950, 1, 1), // ✅ من 1950 وليس 2000
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _selectedDate = newDate;
                _birthDateController.text = _formatDate(newDate);
              });
            },
          ),
        );
      },
    );
  }

  // دالة لتحميل القاعات وتحديد أول قاعة
  // تحميل القاعات
  Future<void> _loadHalls() async {
    setState(() {
      _isLoadingHalls = true;
    });

    try {
      final repo = HallRepository(localDb: getIt());
      _halls = await repo.getAllHalls();

      // إذا كانت هناك قاعات ولم يتم تحديد قاعة بعد
      if (_halls.isNotEmpty && _selectedHallId == null) {
        // إذا كان تعديل، استخدم القاعة المحفوظة
        if (widget.student != null && widget.student!.hallId != null) {
          _selectedHallId = widget.student!.hallId;
          // تحميل الأفواج لهذه القاعة
          await _loadGroups(_selectedHallId!);
        } else {
          // إذا كانت إضافة، اختر أول قاعة
          _selectedHallId = _halls.first.id;
          await _loadGroups(_selectedHallId!);
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل القاعات: $e');
    } finally {
      setState(() {
        _isLoadingHalls = false;
      });
    }
  }

  // تحميل الأفواج حسب القاعة
  Future<void> _loadGroups(int hallId) async {
    setState(() {
      _isLoadingGroups = true;
      _groups = [];
      _selectedGroupId = null;
    });

    try {
      final repo = GroupRepository(localDb: getIt());
      final groups = await repo.getGroupsByHall(hallId);

      setState(() {
        _groups = groups;
      });

      // إذا كان تعديل، حاول تعيين الفوج المحفوظ
      if (widget.student != null && widget.student!.groupId != null) {
        final exists = groups.any((g) => g.id == widget.student!.groupId);
        if (exists) {
          setState(() {
            _selectedGroupId = widget.student!.groupId;
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل الأفواج: $e');
      setState(() {
        _groups = [];
      });
    } finally {
      setState(() {
        _isLoadingGroups = false;
      });
    }
  }

  // عند تغيير القاعة
  void _onHallChanged(int? hallId) {
    setState(() {
      _selectedHallId = hallId;
      _selectedGroupId = null;
      _groups = [];
    });
    if (hallId != null) {
      _loadGroups(hallId);
    }
  }

  // عند تغيير الفوج
  void _onGroupChanged(int? groupId) {
    setState(() {
      _selectedGroupId = groupId;
    });
  }

  // ✅ دالة الحفظ المحسنة (تمنع الضغط المتكرر)
  void _saveStudent() async {
    // منع الضغط إذا كان جاري الحفظ
    if (_isSaving) return;

    // التحقق من الحقول الأساسية
    if (_firstNameController.text.isEmpty) {
      _showError('الاسم الأول مطلوب');
      return;
    }
    if (_lastNameController.text.isEmpty) {
      _showError('اللقب مطلوب');
      return;
    }
    if (_selectedDate == null) {
      _showError('تاريخ الميلاد مطلوب');
      return;
    }

    // تفعيل حالة الحفظ
    setState(() {
      _isSaving = true;
    });

    final student = StudentModel(
      id: widget.student?.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      birthDate: _selectedDate!,
      gender: _gender,
      parentPhone: _parentPhoneController.text.isEmpty
          ? null
          : _parentPhoneController.text,
      enrollmentDate: widget.student?.enrollmentDate ?? DateTime.now(),
      hallId: _selectedHallId, // ✅ حفظ القاعة
      groupId: _selectedGroupId, // ✅ حفظ الفوج
      semester1Grade: _semester1Controller.text.isEmpty
          ? null
          : double.tryParse(_semester1Controller.text),
      semester2Grade: _semester2Controller.text.isEmpty
          ? null
          : double.tryParse(_semester2Controller.text),
      semester3Grade: _semester3Controller.text.isEmpty
          ? null
          : double.tryParse(_semester3Controller.text),
      academicNotes: _academicNotesController.text.isEmpty
          ? null
          : _academicNotesController.text,
      hasChronicDisease: _hasChronicDisease,
      diseaseName: _diseaseNameController.text.isEmpty
          ? null
          : _diseaseNameController.text,
      medications: _medicationsController.text.isEmpty
          ? null
          : _medicationsController.text,
      medicalInstructions: _medicalInstructionsController.text.isEmpty
          ? null
          : _medicalInstructionsController.text,
      doctorName: _doctorNameController.text.isEmpty
          ? null
          : _doctorNameController.text,
      emergencyPhone: _emergencyPhoneController.text.isEmpty
          ? null
          : _emergencyPhoneController.text,
    );

    if (widget.student == null) {
      _studentBloc.add(AddStudentEvent(student));
    } else {
      _studentBloc.add(UpdateStudentEvent(student));
    }
    CustomSnackbar.showSuccess(context, 'جاري الحفظ...');
    //   ScaffoldMessenger.of(context).showSnackBar(
    // const SnackBar(content: Text('جاري الحفظ...')),
    //   );

    // انتظر قليلاً ثم أغلق الشاشة
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _studentBloc.close();
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _parentPhoneController.dispose();
    _semester1Controller.dispose();
    _semester2Controller.dispose();
    _semester3Controller.dispose();
    _academicNotesController.dispose();
    _diseaseNameController.dispose();
    _medicationsController.dispose();
    _medicalInstructionsController.dispose();
    _doctorNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isEdit = widget.student != null;

    // ✅ استخدام AbsorbPointer لمنع الضغط أثناء الحفظ
    return AbsorbPointer(
      absorbing: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'تعديل طالب' : 'إضافة طالب جديد'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'معلومات شخصية', icon: Icon(Icons.person)),
              Tab(text: 'معلومات دراسية', icon: Icon(Icons.school)),
              Tab(text: 'معلومات صحية', icon: Icon(Icons.health_and_safety)),
            ],
          ),
        ),
        body: BlocListener<StudentBloc, StudentState>(
          bloc: _studentBloc,
          listener: (context, state) {
            if (state is StudentOperationSuccess && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            }
            if (state is StudentError && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() {
                _isSaving = false;
              });
            }
          },
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalInfoTab(isMobile),
              _buildAcademicInfoTab(isMobile),
              _buildHealthInfoTab(isMobile),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _saveStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : Text(
                      isEdit ? 'تحديث البيانات' : 'إضافة الطالب',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // باقي الدوال (_buildPersonalInfoTab, _buildAcademicInfoTab, _buildHealthInfoTab)
  // تبقى كما هي دون تغيير

  Widget _buildPersonalInfoTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('الاسم الأول', _firstNameController, Icons.person),
          const SizedBox(height: 16),
          _buildTextField('اللقب', _lastNameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildGenderSelector(),
          const SizedBox(height: 16),
          _buildTextField(
            'رقم هاتف ولي الأمر (اختياري)',
            _parentPhoneController,
            Icons.phone,
            keyboardType: TextInputType.phone,
          ),

          // ==================== اختيار القاعة ====================
          const Text('القاعة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoadingHalls)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
              value: _selectedHallId,
              hint: const Text('-- اختر قاعة --'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- بدون قاعة --'),
                ),
                ..._halls.map((hall) {
                  return DropdownMenuItem(
                    value: hall.id,
                    child: Text(hall.name),
                  );
                }),
              ],
              onChanged: _onHallChanged,
            ),

          const SizedBox(height: 16),

          // ==================== اختيار الفوج ====================
          const Text('الفوج', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoadingGroups)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.group),
              ),
              value: _selectedGroupId,
              hint: const Text('-- اختر فوج --'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- بدون فوج --'),
                ),
                ..._groups.map((group) {
                  return DropdownMenuItem(
                    value: group.id,
                    child: Text(group.name),
                  );
                }),
              ],
              onChanged: _onGroupChanged,
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
          _buildTextField(
            'معدل الفصل الأول (اختياري)',
            _semester1Controller,
            Icons.grade,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'معدل الفصل الثاني (اختياري)',
            _semester2Controller,
            Icons.grade,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'معدل الفصل الثالث (اختياري)',
            _semester3Controller,
            Icons.grade,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'ملاحظات المدرب عن المستوى الدراسي',
            _academicNotesController,
            Icons.note,
            maxLines: 3,
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
          Card(
            child: SwitchListTile(
              title: const Text('هل يعاني الطالب من مرض مزمن؟'),
              value: _hasChronicDisease,
              onChanged: (value) {
                setState(() {
                  _hasChronicDisease = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),
          ),
          if (_hasChronicDisease) ...[
            const SizedBox(height: 16),
            _buildTextField('نوع المرض', _diseaseNameController, Icons.sick),
            const SizedBox(height: 16),
            _buildTextField(
              'الأدوية المستعملة',
              _medicationsController,
              Icons.medication,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'تعليمات طبية خاصة',
              _medicalInstructionsController,
              Icons.healing,
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 16),
          _buildTextField(
            'اسم الطبيب المعالج (اختياري)',
            _doctorNameController,
            Icons.local_hospital,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'رقم هاتف الطوارئ',
            _emergencyPhoneController,
            Icons.emergency,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildDateField() {
    return TextField(
      controller: _birthDateController,
      decoration: InputDecoration(
        labelText: 'تاريخ الميلاد',
        prefixIcon: const Icon(Icons.cake),
        suffixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      readOnly: true,
      onTap: () => _selectDate(context),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الجنس', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('ذكر'),
                selected: _gender == 'ذكر',
                onSelected: (selected) {
                  if (selected) setState(() => _gender = 'ذكر');
                },
                selectedColor: const Color(0xFFE53935),
                labelStyle: TextStyle(
                  color: _gender == 'ذكر' ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChoiceChip(
                label: const Text('أنثى'),
                selected: _gender == 'أنثى',
                onSelected: (selected) {
                  if (selected) setState(() => _gender = 'أنثى');
                },
                selectedColor: const Color(0xFFE53935),
                labelStyle: TextStyle(
                  color: _gender == 'أنثى' ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
