// lib/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/widgets/custom_snackbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _monthlyFeeController = TextEditingController();
  final _insuranceFeeController = TextEditingController();
  final _sessionsPerWeekController = TextEditingController();

  // قائمة الأدوات الرياضية
  List<SportsItem> _sportsItems = [];
  final _newItemNameController = TextEditingController();
  final _newItemPriceController = TextEditingController();

  // قائمة تخفيضات الدفع المسبق
  List<DiscountPackage> _discountPackages = [];
  final _newMonthsController = TextEditingController();
  final _newDiscountController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // تحميل القيم الأساسية
      final monthlyFee = prefs.getDouble('monthly_fee') ?? 2000;
      final insuranceFee = prefs.getDouble('insurance_fee') ?? 1000;
      final sessionsPerWeek = prefs.getInt('sessions_per_week') ?? 3;

      _monthlyFeeController.text = monthlyFee.toString();
      _insuranceFeeController.text = insuranceFee.toString();
      _sessionsPerWeekController.text = sessionsPerWeek.toString();

      // تحميل الأدوات الرياضية
      final sportsItemsJson = prefs.getStringList('sports_items');
      if (sportsItemsJson != null && sportsItemsJson.isNotEmpty) {
        _sportsItems = sportsItemsJson
            .map((json) {
              try {
                final Map<String, dynamic> data = jsonDecode(json);
                return SportsItem(
                  id: data['id'],
                  name: data['name'],
                  price: data['price'].toDouble(),
                );
              } catch (e) {
                print('خطأ في تحليل الأداة: $e');
                return SportsItem(id: 0, name: '', price: 0);
              }
            })
            .where((item) => item.name.isNotEmpty)
            .toList();
      } else {
        _sportsItems = [];
      }

      // تحميل تخفيضات الدفع المسبق
      final discountsJson = prefs.getStringList('discount_packages');
      if (discountsJson != null && discountsJson.isNotEmpty) {
        _discountPackages = discountsJson
            .map((json) {
              try {
                final Map<String, dynamic> data = jsonDecode(json);
                return DiscountPackage(
                  months: data['months'],
                  discount: data['discount'].toDouble(),
                );
              } catch (e) {
                print('خطأ في تحليل التخفيض: $e');
                return DiscountPackage(months: 0, discount: 0);
              }
            })
            .where((pkg) => pkg.months > 0)
            .toList();
      }

      // إذا كانت القائمة فارغة، أضف قيماً افتراضية
      if (_discountPackages.isEmpty) {
        _discountPackages = [
          DiscountPackage(months: 3, discount: 5),
          DiscountPackage(months: 6, discount: 10),
        ];
      }
    } catch (e) {
      print('❌ خطأ في تحميل الإعدادات: $e');
      // قيم افتراضية في حالة الخطأ
      _monthlyFeeController.text = '2000';
      _insuranceFeeController.text = '1000';
      _sessionsPerWeekController.text = '3';
      _sportsItems = [];
      _discountPackages = [
        DiscountPackage(months: 3, discount: 5),
        DiscountPackage(months: 6, discount: 10),
      ];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حفظ القيم الأساسية
      await prefs.setDouble(
        'monthly_fee',
        double.parse(_monthlyFeeController.text),
      );
      await prefs.setDouble(
        'insurance_fee',
        double.parse(_insuranceFeeController.text),
      );
      await prefs.setInt(
        'sessions_per_week',
        int.parse(_sessionsPerWeekController.text),
      );

      // حفظ الأدوات الرياضية
      final sportsItemsJson = _sportsItems
          .map(
            (item) => jsonEncode({
              'id': item.id,
              'name': item.name,
              'price': item.price,
            }),
          )
          .toList();
      await prefs.setStringList('sports_items', sportsItemsJson);

      // حفظ تخفيضات الدفع المسبق
      final discountsJson = _discountPackages
          .map(
            (pkg) =>
                jsonEncode({'months': pkg.months, 'discount': pkg.discount}),
          )
          .toList();
      await prefs.setStringList('discount_packages', discountsJson);

      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'تم حفظ الإعدادات بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ الإعدادات: $e');
      if (!mounted) return;
      CustomSnackbar.showError(context, 'فشل حفظ الإعدادات: $e');
    }
  }

  void _addSportsItem() {
    if (_newItemNameController.text.isEmpty ||
        _newItemPriceController.text.isEmpty) {
      CustomSnackbar.showError(context, 'الرجاء إدخال اسم وسعر الأداة');
      return;
    }

    setState(() {
      _sportsItems.add(
        SportsItem(
          id: DateTime.now().millisecondsSinceEpoch,
          name: _newItemNameController.text,
          price: double.parse(_newItemPriceController.text),
        ),
      );
      _newItemNameController.clear();
      _newItemPriceController.clear();
    });
  }

  void _removeSportsItem(int id) {
    setState(() {
      _sportsItems.removeWhere((item) => item.id == id);
    });
  }

  void _addDiscountPackage() {
    if (_newMonthsController.text.isEmpty ||
        _newDiscountController.text.isEmpty) {
      CustomSnackbar.showError(
        context,
        'الرجاء إدخال عدد الأشهر ونسبة التخفيض',
      );
      return;
    }

    final months = int.tryParse(_newMonthsController.text);
    final discount = double.tryParse(_newDiscountController.text);

    if (months == null || discount == null) {
      CustomSnackbar.showError(context, 'الرجاء إدخال أرقام صحيحة');
      return;
    }

    setState(() {
      _discountPackages.add(
        DiscountPackage(months: months, discount: discount),
      );
      _newMonthsController.clear();
      _newDiscountController.clear();
    });
  }

  void _removeDiscountPackage(int months) {
    setState(() {
      _discountPackages.removeWhere((pkg) => pkg.months == months);
    });
  }

  @override
  void dispose() {
    _monthlyFeeController.dispose();
    _insuranceFeeController.dispose();
    _sessionsPerWeekController.dispose();
    _newItemNameController.dispose();
    _newItemPriceController.dispose();
    _newMonthsController.dispose();
    _newDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل الإعدادات...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // الإعدادات المالية الأساسية
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: Color(0xFFE53935)),
                      const SizedBox(width: 12),
                      const Text(
                        'الإعدادات المالية الأساسية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _monthlyFeeController,
                    decoration: const InputDecoration(
                      labelText: 'قيمة الاشتراك الشهري (دج)',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _insuranceFeeController,
                    decoration: const InputDecoration(
                      labelText: 'حقوق التسجيل السنوية (دج)',
                      prefixIcon: Icon(Icons.security),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sessionsPerWeekController,
                    decoration: const InputDecoration(
                      labelText: 'عدد الحصص في الأسبوع',
                      prefixIcon: Icon(Icons.fitness_center),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // الأدوات الرياضية
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_martial_arts,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'الأدوات الرياضية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // قائمة الأدوات الموجودة
                  ..._sportsItems.map(
                    (item) => ListTile(
                      leading: const Icon(
                        Icons.shopping_bag,
                        color: Colors.orange,
                      ),
                      title: Text(item.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.price.toStringAsFixed(0)} دج',
                            style: const TextStyle(color: Colors.green),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeSportsItem(item.id),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_sportsItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'لا توجد أدوات مسجلة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  const Divider(),

                  // إضافة أداة جديدة
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _newItemNameController,
                          decoration: const InputDecoration(
                            hintText: 'اسم الأداة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _newItemPriceController,
                          decoration: const InputDecoration(
                            hintText: 'السعر',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addSportsItem,
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFFE53935),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // تخفيضات الدفع المسبق
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer, color: Color(0xFFE53935)),
                      const SizedBox(width: 12),
                      const Text(
                        'تخفيضات الدفع المسبق',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // قائمة التخفيضات الموجودة
                  ..._discountPackages.map(
                    (pkg) => ListTile(
                      leading: const Icon(Icons.percent, color: Colors.green),
                      title: Text('${pkg.months} أشهر'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${pkg.discount.toStringAsFixed(0)}% تخفيض',
                            style: const TextStyle(color: Colors.green),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDiscountPackage(pkg.months),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(),

                  // إضافة تخفيض جديد
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newMonthsController,
                          decoration: const InputDecoration(
                            hintText: 'عدد الأشهر (3 أو 6)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _newDiscountController,
                          decoration: const InputDecoration(
                            hintText: 'نسبة التخفيض (%)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addDiscountPackage,
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFFE53935),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // زر حفظ في الأسفل
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('حفظ الإعدادات', style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// نماذج البيانات
class SportsItem {
  final int id;
  final String name;
  final double price;

  SportsItem({required this.id, required this.name, required this.price});
}

class DiscountPackage {
  final int months;
  final double discount;

  DiscountPackage({required this.months, required this.discount});
}
