// lib/presentation/screens/add_belt_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/belt_model.dart';
import '../../data/repositories/belt_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

class AddBeltScreen extends StatefulWidget {
  final int studentId;
  final VoidCallback onBeltAdded;

  const AddBeltScreen({
    super.key,
    required this.studentId,
    required this.onBeltAdded,
  });

  @override
  State<AddBeltScreen> createState() => _AddBeltScreenState();
}

class _AddBeltScreenState extends State<AddBeltScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _coachNameController = TextEditingController();

  String _selectedBelt = 'أبيض';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // قائمة الأحزمة بالترتيب
  final List<Map<String, dynamic>> _belts = [
    {'name': 'أبيض', 'order': 1, 'color': Colors.grey.shade100},
    {'name': 'أصفر', 'order': 2, 'color': Colors.yellow.shade700},
    {'name': 'برتقالي', 'order': 3, 'color': Colors.orange},
    {'name': 'أخضر', 'order': 4, 'color': Colors.green},
    {'name': 'أزرق', 'order': 5, 'color': Colors.blue},
    {'name': 'بني', 'order': 6, 'color': Colors.brown},
    {'name': 'أسود', 'order': 7, 'color': Colors.black},
  ];

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'DZ'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveBelt() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final belt = _belts.firstWhere((b) => b['name'] == _selectedBelt);
        final orderIndex = belt['order'] as int;

        final beltModel = BeltModel(
          studentId: widget.studentId,
          beltColor: _selectedBelt,
          dateAchieved: _selectedDate,
          coachName: _coachNameController.text.isEmpty
              ? null
              : _coachNameController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          orderIndex: orderIndex,
        );

        final repo = BeltRepository(localDb: getIt());
        await repo.addBelt(beltModel);

        if (!mounted) return;
        CustomSnackbar.showSuccess(context, 'تم تسجيل ترقية الحزام بنجاح');
        widget.onBeltAdded();
        Navigator.pop(context, true);
      } catch (e) {
        print('❌ خطأ في حفظ الحزام: $e');
        CustomSnackbar.showError(context, 'فشل حفظ الترقية');
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ترقية الحزام')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // اختيار لون الحزام
            const Text(
              'لون الحزام الجديد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              value: _selectedBelt,
              items: _belts.map((belt) {
                return DropdownMenuItem<String>(
                  value: belt['name'] as String,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: belt['color'],
                          shape: BoxShape.circle,
                          border: belt['name'] == 'أبيض'
                              ? Border.all(color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(belt['name'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBelt = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // تاريخ الترقية
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاريخ الترقية',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // اسم المدرب (اختياري)
            TextFormField(
              controller: _coachNameController,
              decoration: const InputDecoration(
                labelText: 'اسم المدرب (اختياري)',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ملاحظات (اختياري)
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // زر الحفظ
            ElevatedButton(
              onPressed: _isSaving ? null : _saveBelt,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 50),
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
                  : const Text('تسجيل الترقية'),
            ),
          ],
        ),
      ),
    );
  }
}
