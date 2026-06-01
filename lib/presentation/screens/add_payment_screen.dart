// lib/presentation/screens/add_payment_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

class AddPaymentScreen extends StatefulWidget {
  final int? studentId;
  final VoidCallback onPaymentAdded;
  const AddPaymentScreen({
    super.key,
    this.studentId,
    required this.onPaymentAdded,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentType = 'monthly';
  int? _selectedMonth;
  int? _selectedYear;
  DateTime _selectedDate = DateTime.now();
  bool _isGifted = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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

  void _savePayment() async {
    if (_formKey.currentState!.validate()) {
      if (_isSaving) return;

      setState(() {
        _isSaving = true;
      });

      try {
        // إنشاء كائن الدفعة
        final payment = PaymentModel(
          studentId: widget.studentId ?? 1,
          amount: double.parse(_amountController.text),
          paymentDate: _selectedDate,
          paymentType: _paymentType,
          month: _selectedMonth ?? DateTime.now().month,
          year: _selectedYear ?? DateTime.now().year,
          isExtra: _paymentType == 'extra',
          extraReason: _paymentType == 'extra' ? _reasonController.text : null,
          isGifted: _isGifted,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );

        // حفظ الدفعة في قاعدة البيانات
        final paymentRepo = PaymentRepository(localDb: getIt());
        await paymentRepo.addPayment(payment);

        print(
          '✅ تم حفظ الدفعة بنجاح: student_id=${payment.studentId}, amount=${payment.amount}, type=${payment.paymentType}',
        );

        if (!mounted) return;
        CustomSnackbar.showSuccess(context, 'تم تسجيل الدفعة بنجاح');
        widget.onPaymentAdded();
        Navigator.pop(context, true);
      } catch (e) {
        print('❌ خطأ في حفظ الدفعة: $e');
        if (!mounted) return;
        CustomSnackbar.showError(context, 'فشل حفظ الدفعة: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دفعة جديدة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // نوع الدفعة
            const Text(
              'نوع الدفعة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'monthly',
                  label: Text('اشتراك شهري'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: 'insurance',
                  label: Text('حقوق التأمين'),
                  icon: Icon(Icons.security),
                ),
                ButtonSegment(
                  value: 'extra',
                  label: Text('مستحقات إضافية'),
                  icon: Icon(Icons.shopping_bag),
                ),
              ],
              selected: {_paymentType},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _paymentType = selection.first;
                });
              },
            ),

            const SizedBox(height: 16),

            // المبلغ
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'المبلغ (دج)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'المبلغ مطلوب';
                }
                if (double.tryParse(value) == null) {
                  return 'يرجى إدخال رقم صحيح';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // التاريخ
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الدفع',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),

            // إذا كان نوع الدفعة اشتراك شهري
            if (_paymentType == 'monthly') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'الشهر',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedMonth ?? DateTime.now().month,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text('شهر ${index + 1}'),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'السنة',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedYear ?? DateTime.now().year,
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],

            // إذا كان نوع الدفعة مستحقات إضافية
            if (_paymentType == 'extra') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب المستحقات الإضافية',
                  prefixIcon: Icon(Icons.receipt),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'السبب مطلوب للمستحقات الإضافية';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 16),

            // هل هي إهداء؟
            SwitchListTile(
              title: const Text('إهداء (بدون دفع)'),
              subtitle: const Text('تفعيل إذا كانت المستحقات مجانية للطالب'),
              value: _isGifted,
              onChanged: (value) {
                setState(() {
                  _isGifted = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),

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

            ElevatedButton(
              onPressed: _isSaving ? null : _savePayment,
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
                  : const Text('تسجيل الدفعة', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
