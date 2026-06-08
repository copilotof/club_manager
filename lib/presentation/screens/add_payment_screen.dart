// lib/presentation/screens/add_payment_screen_v2.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

class AddPaymentScreenV2 extends StatefulWidget {
  final int studentId;
  final VoidCallback onPaymentAdded;
  final int? initialYear;

  const AddPaymentScreenV2({
    super.key,
    required this.studentId,
    required this.onPaymentAdded,
    this.initialYear,
  });

  @override
  State<AddPaymentScreenV2> createState() => _AddPaymentScreenV2State();
}

class _AddPaymentScreenV2State extends State<AddPaymentScreenV2> {
  // ==================== المتغيرات الأساسية ====================
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  // تخزين الأشهر المكتملة لكل سنة
  Map<int, Map<int, bool>> _completedMonthsByYear = {};

  String _paymentType = 'monthly'; // monthly, insurance, extra
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _selectedDate = DateTime.now();
  bool _isGifted = false;
  bool _isSaving = false;

  // ==================== الإعدادات من SharedPreferences ====================
  double _monthlyFee = 2000;
  double _insuranceFee = 1000;
  List<Map<String, dynamic>> _discountPackages = [];

  // ==================== البيانات المحفوظة من قاعدة البيانات ====================
  Map<int, double> _monthlyPaid = {}; // المبلغ المدفوع لكل شهر
  Map<int, double> _insurancePaid = {}; // المبلغ المدفوع للتأمين لكل سنة
  Set<int> _completedMonths = {}; // الأشهر المكتملة في السنة الحالية
  bool _isInsuranceComplete = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _loadSettings();
    _loadStudentData();
  }

  // ==================== تحميل الإعدادات ====================

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyFee = prefs.getDouble('monthly_fee') ?? 2000;
      _insuranceFee = prefs.getDouble('insurance_fee') ?? 1000;

      // ✅ تحميل تخفيضات الدفع المسبق من الإعدادات
      final discountsJson = prefs.getStringList('discount_packages');
      if (discountsJson != null && discountsJson.isNotEmpty) {
        _discountPackages = discountsJson.map((json) {
          final Map<String, dynamic> data = jsonDecode(json);
          return {
            'months': data['months'],
            'discount': (data['discount'] as num).toDouble(),
          };
        }).toList();
      } else {
        _discountPackages = []; // ✅ فارغة إذا لم توجد في الإعدادات
      }
    });
  }

  // ==================== تحميل بيانات الطالب ====================
  Future<void> _loadStudentData() async {
    final repo = PaymentRepository(localDb: getIt());
    final allPayments = await repo.getStudentPayments(widget.studentId);

    // إعادة تعيين المتغيرات
    _monthlyPaid.clear();
    _completedMonths.clear();
    _insurancePaid.clear();

    // ✅ متغير جديد: تخزين الأشهر المكتملة لكل سنة
    _completedMonthsByYear = {};

    for (var payment in allPayments) {
      if (payment.paymentType == 'monthly') {
        // دفعات الاشتراك الشهري العادية
        if (payment.targetMonth != null && payment.targetYear != null) {
          final month = payment.targetMonth!;
          final year = payment.targetYear!;

          if (year == _selectedYear) {
            _monthlyPaid[month] = (_monthlyPaid[month] ?? 0) + payment.amount;
            if ((_monthlyPaid[month] ?? 0) >= _monthlyFee) {
              _completedMonths.add(month);
              // ✅ تخزين للسنة الحالية
              if (!_completedMonthsByYear.containsKey(year)) {
                _completedMonthsByYear[year] = {};
              }
              _completedMonthsByYear[year]![month] = true;
            }
          }
        }

        // ✅ دفعات مسبقة (عدة أشهر تمتد لسنة أو سنتين)
        if (payment.prepaidStartMonth != null &&
            payment.prepaidEndMonth != null) {
          int startMonth = payment.prepaidStartMonth!;
          int endMonth = payment.prepaidEndMonth!;
          int startYear = payment.targetYear ?? _selectedYear;

          print(
            '🎯 دفعة مسبقة: أشهر $startMonth إلى $endMonth (سنة البداية $startYear)',
          );

          int currentMonth = startMonth;
          int currentYear = startYear;

          // حساب عدد الأشهر في الدفعة المسبقة
          int monthsCount;
          if (endMonth >= startMonth) {
            monthsCount = endMonth - startMonth + 1;
          } else {
            monthsCount = (12 - startMonth + 1) + endMonth;
          }

          for (int i = 0; i < monthsCount; i++) {
            int actualMonth = currentMonth;
            int actualYear = currentYear;

            if (actualMonth > 12) {
              actualMonth -= 12;
              actualYear++;
            }

            print('   ✅ شهر $actualMonth/$actualYear مكتمل');

            // ✅ تخزين لكل سنة على حدة
            if (!_completedMonthsByYear.containsKey(actualYear)) {
              _completedMonthsByYear[actualYear] = {};
            }
            _completedMonthsByYear[actualYear]![actualMonth] = true;

            // إذا كانت السنة هي السنة المختارة حالياً
            if (actualYear == _selectedYear) {
              _completedMonths.add(actualMonth);
            }

            currentMonth++;
            if (currentMonth > 12) {
              currentMonth = 1;
              currentYear++;
            }
          }
        }
      }

      // دفعات التأمين
      if (payment.paymentType == 'insurance' &&
          payment.targetYear == _selectedYear) {
        _insurancePaid[_selectedYear] =
            (_insurancePaid[_selectedYear] ?? 0) + payment.amount;
      }
    }

    _isInsuranceComplete =
        (_insurancePaid[_selectedYear] ?? 0) >= _insuranceFee;

    // ✅ طباعة للتأكد
    print('📊 الأشهر المكتملة حسب السنة:');
    for (var year in _completedMonthsByYear.keys) {
      print('   السنة $year: ${_completedMonthsByYear[year]!.keys.toList()}');
    }

    setState(() {
      _updateAmountField();
    });
  }

  // ==================== تحديث حقل المبلغ ====================
  void _updateAmountField() {
    if (_paymentType == 'monthly') {
      // ✅ التحقق من اكتمال الشهر في السنة الحالية
      bool isComplete =
          _completedMonthsByYear[_selectedYear]?[_selectedMonth] == true;

      if (isComplete) {
        _amountController.text = '0';
      } else {
        final paid = _monthlyPaid[_selectedMonth] ?? 0;
        final remaining = _monthlyFee - paid;
        _amountController.text = remaining > 0 ? remaining.toString() : '0';
      }
    } else if (_paymentType == 'insurance') {
      if (_isInsuranceComplete) {
        _amountController.text = '0';
      } else {
        final remaining = _insuranceFee - (_insurancePaid[_selectedYear] ?? 0);
        _amountController.text = remaining > 0 ? remaining.toString() : '0';
      }
    } else if (_paymentType == 'extra') {
      _amountController.text = '';
    }
  }

  // ==================== هل النوع الحالي مكتمل؟ ====================
  bool get _isCurrentTypeComplete {
    if (_paymentType == 'monthly') {
      return _completedMonthsByYear[_selectedYear]?[_selectedMonth] == true;
    } else if (_paymentType == 'insurance') {
      return _isInsuranceComplete;
    }
    return false;
  }

  // ==================== الدفع المسبق ====================
  Future<void> _applyPrepaidDiscount(int months, double discount) async {
    // حساب الأشهر المشمولة
    int startMonth = _selectedMonth;
    int startYear = _selectedYear;
    List<int> targetMonths = [];
    List<int> targetYears = [];

    int tempMonth = startMonth;
    int tempYear = startYear;

    for (int i = 0; i < months; i++) {
      targetMonths.add(tempMonth);
      targetYears.add(tempYear);
      tempMonth++;
      if (tempMonth > 12) {
        tempMonth = 1;
        tempYear++;
      }
    }

    final endMonth = targetMonths.last;
    final endYear = targetYears.last;

    // بناء نص الأشهر للعرض
    List<String> monthNames = [];
    for (int i = 0; i < targetMonths.length; i++) {
      monthNames.add('${_getMonthName(targetMonths[i])} ${targetYears[i]}');
    }

    // حساب المبلغ
    double totalAmount = _monthlyFee * months;
    double discountedAmount = totalAmount * (1 - discount / 100);

    // تأكيد
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الدفع المسبق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عدد الأشهر: $months',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('الخصم: ${discount.toStringAsFixed(0)}%'),
            Text('المبلغ: ${discountedAmount.toStringAsFixed(0)} دج'),
            const Divider(),
            const Text(
              'الأشهر المشمولة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(monthNames.join('، '), style: const TextStyle(fontSize: 12)),
            if (endYear > startYear)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ تشمل سنتين ($startYear و $endYear)',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
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
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final payment = PaymentModel(
        studentId: widget.studentId,
        amount: discountedAmount,
        paymentDate: _selectedDate,
        paymentType: 'monthly',
        month: startMonth,
        year: startYear,
        isGifted: _isGifted,
        discountMonths: months,
        discountPercentage: discount,
        isFullyPaid: true,
        targetMonth: startMonth,
        targetYear: startYear,
        prepaidMonths: months,
        prepaidStartMonth: startMonth,
        prepaidEndMonth: endMonth,
      );

      final repo = PaymentRepository(localDb: getIt());
      await repo.addPayment(payment);
      await _loadStudentData();

      if (!mounted) return;
      CustomSnackbar.showSuccess(
        context,
        '✓ تم تسديد ${monthNames.join('، ')}',
      );
      widget.onPaymentAdded();
      Navigator.pop(context, true);
    } catch (e) {
      CustomSnackbar.showError(context, 'فشل حفظ الدفعة');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== حفظ دفعة عادية ====================
  Future<void> _savePayment() async {
    if (_isCurrentTypeComplete && _paymentType != 'extra') {
      CustomSnackbar.showWarning(context, '✓ هذا الشهر مكتمل بالفعل');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 && _paymentType != 'extra') {
      CustomSnackbar.showWarning(context, 'الرجاء إدخال مبلغ أكبر من 0');
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final payment = PaymentModel(
          studentId: widget.studentId,
          amount: amount,
          paymentDate: _selectedDate,
          paymentType: _paymentType,
          month: _paymentType == 'monthly' ? _selectedMonth : null,
          year: _paymentType == 'monthly' ? _selectedYear : _selectedYear,
          isExtra: _paymentType == 'extra',
          extraReason: _paymentType == 'extra' ? _reasonController.text : null,
          isGifted: _isGifted,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          targetMonth: _paymentType == 'monthly' ? _selectedMonth : null,
          targetYear: _selectedYear,
        );

        final repo = PaymentRepository(localDb: getIt());
        await repo.addPayment(payment);
        await _loadStudentData();

        if (!mounted) return;
        CustomSnackbar.showSuccess(context, 'تم تسجيل الدفعة بنجاح');
        widget.onPaymentAdded();
        Navigator.pop(context, true);
      } catch (e) {
        CustomSnackbar.showError(context, 'فشل حفظ الدفعة');
      } finally {
        if (mounted) setState(() => _isSaving = false);
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
            setState(() => _selectedDate = newDate);
          },
        ),
      ),
    );
  }

  // ==================== دوال مساعدة ====================
  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'ماي',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }

  List<int> _getAvailableYears() {
    final currentYear = DateTime.now().year;
    return [currentYear - 2, currentYear - 1, currentYear, currentYear + 1];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ==================== واجهة المستخدم ====================
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
                ButtonSegment(value: 'monthly', label: Text('اشتراك شهري')),
                ButtonSegment(value: 'insurance', label: Text('حقوق التأمين')),
                ButtonSegment(value: 'extra', label: Text('مستحقات إضافية')),
              ],
              selected: {_paymentType},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _paymentType = selection.first;
                  _updateAmountField();
                });
              },
            ),

            const SizedBox(height: 16),

            // تخفيضات الدفع المسبق
            if (_paymentType == 'monthly' && _discountPackages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تخفيض الدفع المسبق',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _discountPackages.map((pkg) {
                      int months = pkg['months'] as int;
                      double discount = (pkg['discount'] as num).toDouble();
                      double discountedAmount =
                          _monthlyFee * months * (1 - discount / 100);
                      // ✅ تعطيل الزر إذا كان الشهر الحالي مكتملاً
                      final isDisabled = _isCurrentTypeComplete;
                      return ElevatedButton(
                        onPressed: isDisabled
                            ? null
                            : () => _applyPrepaidDiscount(months, discount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDisabled
                              ? Colors.grey.shade300
                              : Colors.green.shade100,
                          foregroundColor: isDisabled
                              ? Colors.grey.shade600
                              : Colors.green.shade800,
                        ),
                        child: Text(
                          '$months أشهر (${discountedAmount.toStringAsFixed(0)} دج)',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            /*          
            // تخفيضات الدفع المسبق
            if (_paymentType == 'monthly' && !_isCurrentTypeComplete)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تخفيض الدفع المسبق',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _discountPackages.map((pkg) {
                      int months = pkg['months'] as int;
                      // ✅ تحويل discount إلى double بشكل آمن
                      double discount = (pkg['discount'] as num).toDouble();
                      double discountedAmount =
                          _monthlyFee * months * (1 - discount / 100);
                      return ElevatedButton(
                        onPressed: () =>
                            _applyPrepaidDiscount(months, discount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade800,
                        ),
                        child: Text(
                          '$months أشهر (${discountedAmount.toStringAsFixed(0)} دج)',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
*/
            // المبلغ
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'المبلغ (دج)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              readOnly: _isCurrentTypeComplete && _paymentType != 'extra',
            ),

            const SizedBox(height: 16),

            // التاريخ
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاريخ الدفع',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),

            // اختيار الشهر والسنة (للاشتراك الشهري فقط)
            if (_paymentType == 'monthly') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 0,
                        maxWidth: double.infinity,
                      ),
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'الشهر',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        value: _selectedMonth,
                        isExpanded: true,
                        items: List.generate(12, (index) {
                          int month = index + 1;
                          // ✅ التحقق من اكتمال الشهر في السنة الحالية
                          bool isCompleted =
                              _completedMonthsByYear[_selectedYear]?[month] ==
                              true;
                          return DropdownMenuItem(
                            value: month,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _getMonthName(month),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCompleted) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            _selectedMonth = value!;
                            _updateAmountField();
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 0,
                        maxWidth: double.infinity,
                      ),
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'السنة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        value: _selectedYear,
                        isExpanded: true,
                        items: _getAvailableYears().map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedYear = value!;
                          });
                          await _loadStudentData();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // اختيار السنة للتأمين
            if (_paymentType == 'insurance') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  border: OutlineInputBorder(),
                ),
                value: _selectedYear,
                items: _getAvailableYears().map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedYear = value!;
                  });
                  await _loadStudentData();
                },
              ),
            ],

            // مستحقات إضافية
            if (_paymentType == 'extra') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'السبب',
                  prefixIcon: Icon(Icons.receipt),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'السبب مطلوب' : null,
              ),
            ],

            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('إهداء'),
              value: _isGifted,
              onChanged: (v) => setState(() => _isGifted = v),
              activeColor: const Color(0xFFE53935),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: (_isSaving || _isCurrentTypeComplete)
                  ? null
                  : _savePayment,
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
                  : Text(_isCurrentTypeComplete ? '✓ مكتمل' : 'تسجيل الدفعة'),
            ),

            if (_isCurrentTypeComplete && _paymentType != 'extra')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _paymentType == 'monthly'
                              ? '✓ اشتراك شهر ${_getMonthName(_selectedMonth)} $_selectedYear مكتمل'
                              : '✓ حقوق التأمين $_selectedYear مكتملة',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
