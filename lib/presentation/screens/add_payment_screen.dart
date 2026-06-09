// lib/presentation/screens/add_payment_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

// نموذج الأداة الرياضية
class SportsItem {
  final int id;
  final String name;
  final double price;

  SportsItem({required this.id, required this.name, required this.price});

  factory SportsItem.fromMap(Map<String, dynamic> map) {
    return SportsItem(
      id: map['id'],
      name: map['name'],
      price: map['price'].toDouble(),
    );
  }
}

class AddPaymentScreen extends StatefulWidget {
  final int studentId;
  final VoidCallback onPaymentAdded;
  final int? initialYear;

  const AddPaymentScreen({
    super.key,
    required this.studentId,
    required this.onPaymentAdded,
    this.initialYear,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  // ==================== المتغيرات الأساسية ====================
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // تخزين الأشهر المكتملة لكل سنة
  Map<int, Map<int, bool>> _completedMonthsByYear = {};

  String _paymentType = 'monthly'; // monthly, insurance, extra
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _selectedDate = DateTime.now();
  bool _isGifted = false;
  bool _isSaving = false;

  // للأدوات الرياضية (مستحقات إضافية)
  List<SportsItem> _sportsItems = [];
  SportsItem? _selectedSportsItem;

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

      // تحميل تخفيضات الدفع المسبق
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
        _discountPackages = [];
      }

      // تحميل الأدوات الرياضية من الإعدادات
      final sportsItemsJson = prefs.getStringList('sports_items');
      if (sportsItemsJson != null && sportsItemsJson.isNotEmpty) {
        _sportsItems = sportsItemsJson.map((json) {
          final Map<String, dynamic> data = jsonDecode(json);
          return SportsItem(
            id: data['id'],
            name: data['name'],
            price: data['price'].toDouble(),
          );
        }).toList();
      } else {
        _sportsItems = [];
      }
    });
  }

  void _onSportsItemSelected(SportsItem? item) {
    setState(() {
      _selectedSportsItem = item;
      if (item != null) {
        _amountController.text = item.price.toString();
      } else {
        _amountController.text = '';
      }
    });
  }

  // ==================== تحميل بيانات الطالب ====================
  Future<void> _loadStudentData() async {
    final repo = PaymentRepository(localDb: getIt());
    final allPayments = await repo.getStudentPayments(widget.studentId);

    _monthlyPaid.clear();
    _completedMonths.clear();
    _insurancePaid.clear();
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
              if (!_completedMonthsByYear.containsKey(year)) {
                _completedMonthsByYear[year] = {};
              }
              _completedMonthsByYear[year]![month] = true;
            }
          }
        }

        // دفعات مسبقة (عدة أشهر تمتد لسنة أو سنتين)
        if (payment.prepaidStartMonth != null &&
            payment.prepaidEndMonth != null) {
          int startMonth = payment.prepaidStartMonth!;
          int endMonth = payment.prepaidEndMonth!;
          int startYear = payment.targetYear ?? _selectedYear;

          int currentMonth = startMonth;
          int currentYear = startYear;

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

            if (!_completedMonthsByYear.containsKey(actualYear)) {
              _completedMonthsByYear[actualYear] = {};
            }
            _completedMonthsByYear[actualYear]![actualMonth] = true;

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

    setState(() {
      _updateAmountField();
    });
  }

  // ==================== تحديث حقل المبلغ ====================
  void _updateAmountField() {
    if (_paymentType == 'monthly') {
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
      // لا نغير المبلغ هنا، بل يتم تعبئته من اختيار الأداة
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

    List<String> monthNames = [];
    for (int i = 0; i < targetMonths.length; i++) {
      monthNames.add('${_getMonthName(targetMonths[i])} ${targetYears[i]}');
    }

    double totalAmount = _monthlyFee * months;
    double discountedAmount = totalAmount * (1 - discount / 100);

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

  // ==================== حفظ دفعة ====================
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
        String? extraReason;
        if (_paymentType == 'extra') {
          if (_selectedSportsItem != null) {
            extraReason = _selectedSportsItem!.name;
          } else {
            extraReason = 'مستحقات إضافية';
          }
        }

        final payment = PaymentModel(
          studentId: widget.studentId,
          amount: amount,
          paymentDate: _selectedDate,
          paymentType: _paymentType,
          month: _paymentType == 'monthly' ? _selectedMonth : null,
          year: _paymentType == 'monthly' ? _selectedYear : _selectedYear,
          isExtra: _paymentType == 'extra',
          extraReason: extraReason,
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
            // 1. نوع الدفعة
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
                  if (_paymentType != 'extra') {
                    _selectedSportsItem = null;
                  }
                  _updateAmountField();
                });
              },
            ),

            const SizedBox(height: 16),

            // 2. تخفيضات الدفع المسبق (للاشتراك الشهري فقط)
            if (_paymentType == 'monthly' &&
                _discountPackages.isNotEmpty &&
                !_isCurrentTypeComplete)
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

            // 3. المبلغ (للمستحقات الإضافية نضعه داخل القسم الخاص)
            if (_paymentType != 'extra') ...[
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
            ],

            // 4. مستحقات إضافية (كل الحقول موجودة هنا)
            if (_paymentType == 'extra') ...[
              // قائمة الأدوات الرياضية
              DropdownButtonFormField<SportsItem>(
                decoration: const InputDecoration(
                  labelText: 'اختر الأداة الرياضية',
                  prefixIcon: Icon(Icons.shopping_bag),
                  border: OutlineInputBorder(),
                ),
                value: _selectedSportsItem,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<SportsItem>(
                    value: null,
                    child: Text('-- اختر أداة --'),
                  ),
                  ..._sportsItems.map((item) {
                    return DropdownMenuItem<SportsItem>(
                      value: item,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.name),
                          Text(
                            '${item.price.toStringAsFixed(0)} دج',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _onSportsItemSelected,
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
            ],

            // 5. التاريخ (للمستحقات الإضافية نضعه داخل القسم الخاص)
            if (_paymentType != 'extra') ...[
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
              const SizedBox(height: 16),
            ],

            // 6. الإهداء (للمستحقات الإضافية نضعه داخل القسم الخاص)
            if (_paymentType != 'extra') ...[
              SwitchListTile(
                title: const Text('إهداء'),
                subtitle: const Text('تفعيل إذا كانت المستحقات مجانية للطالب'),
                value: _isGifted,
                onChanged: (v) => setState(() => _isGifted = v),
                activeColor: const Color(0xFFE53935),
              ),
              const SizedBox(height: 16),
            ],

            // 7. الإهداء للمستحقات الإضافية
            if (_paymentType == 'extra') ...[
              SwitchListTile(
                title: const Text('إهداء'),
                subtitle: const Text('تفعيل إذا كانت المستحقات مجانية للطالب'),
                value: _isGifted,
                onChanged: (v) => setState(() => _isGifted = v),
                activeColor: const Color(0xFFE53935),
              ),
              const SizedBox(height: 16),
            ],

            // 8. التاريخ للمستحقات الإضافية
            if (_paymentType == 'extra') ...[
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
              const SizedBox(height: 16),
            ],

            // 9. الملاحظات (للجميع)
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // 10. اختيار الشهر والسنة (للاشتراك الشهري فقط)
            if (_paymentType == 'monthly') ...[
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
                    child: DropdownButtonFormField<int>(
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
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 11. اختيار السنة للتأمين
            if (_paymentType == 'insurance') ...[
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
              const SizedBox(height: 16),
            ],

            // 12. زر الحفظ
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

            // رسالة اكتمال الدفعة
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
