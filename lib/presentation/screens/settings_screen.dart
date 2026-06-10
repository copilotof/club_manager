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

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ==================== الإعدادات المالية ====================
  final _monthlyFeeController = TextEditingController();
  final _insuranceFeeController = TextEditingController();
  final _sessionsPerWeekController = TextEditingController();

  // ==================== الأدوات الرياضية ====================
  List<SportsItem> _sportsItems = [];
  final _newItemNameController = TextEditingController();
  final _newItemPriceController = TextEditingController();

  // ==================== تخفيضات الدفع المسبق ====================
  List<DiscountPackage> _discountPackages = [];
  final _newMonthsController = TextEditingController();
  final _newDiscountController = TextEditingController();

  // ==================== الإعدادات الرياضية (اختصاصات وفئات عمرية) ====================
  List<SpecialtyItem> _specialties = [];
  final _newSpecialtyController = TextEditingController();
  final _newAgeCategoryController = TextEditingController();
  final _newMinAgeController = TextEditingController();
  final _newMaxAgeController = TextEditingController();
  int? _selectedSpecialtyId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // القيم الأساسية
      _monthlyFeeController.text =
          prefs.getDouble('monthly_fee')?.toString() ?? '2000';
      _insuranceFeeController.text =
          prefs.getDouble('insurance_fee')?.toString() ?? '1000';
      _sessionsPerWeekController.text =
          prefs.getInt('sessions_per_week')?.toString() ?? '3';

      // الأدوات الرياضية
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
      }

      // تخفيضات الدفع المسبق
      final discountsJson = prefs.getStringList('discount_packages');
      if (discountsJson != null && discountsJson.isNotEmpty) {
        _discountPackages = discountsJson.map((json) {
          final Map<String, dynamic> data = jsonDecode(json);
          return DiscountPackage(
            months: data['months'],
            discount: data['discount'].toDouble(),
          );
        }).toList();
      }

      // الاختصاصات الرياضية
      final specialtiesJson = prefs.getString('sports_specialties');
      if (specialtiesJson != null && specialtiesJson.isNotEmpty) {
        final List<dynamic> data = jsonDecode(specialtiesJson);
        _specialties = data.map((s) => SpecialtyItem.fromJson(s)).toList();
      } else {
        // بيانات افتراضية
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
      print('خطأ في تحميل الإعدادات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

      // حفظ الاختصاصات الرياضية
      final specialtiesJson = jsonEncode(
        _specialties.map((s) => s.toJson()).toList(),
      );
      await prefs.setString('sports_specialties', specialtiesJson);

      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'تم حفظ الإعدادات بنجاح');
    } catch (e) {
      print('خطأ في حفظ الإعدادات: $e');
      if (!mounted) return;
      CustomSnackbar.showError(context, 'فشل حفظ الإعدادات');
    }
  }

  // ==================== دوال الأدوات الرياضية ====================
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

  // ==================== دوال تخفيضات الدفع المسبق ====================
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

  // ==================== دوال الاختصاصات الرياضية ====================
  void _addSpecialty() {
    if (_newSpecialtyController.text.isEmpty) {
      CustomSnackbar.showError(context, 'الرجاء إدخال اسم الاختصاص');
      return;
    }

    final newId = _specialties.isNotEmpty ? _specialties.last.id + 1 : 1;
    setState(() {
      _specialties.add(
        SpecialtyItem(
          id: newId,
          name: _newSpecialtyController.text,
          ageCategories: [],
        ),
      );
      _newSpecialtyController.clear();
    });
  }

  void _removeSpecialty(int id) {
    setState(() {
      _specialties.removeWhere((s) => s.id == id);
    });
  }

  void _addAgeCategory(int specialtyId) {
    final name = _newAgeCategoryController.text.trim();
    final minAge = int.tryParse(_newMinAgeController.text.trim());
    final maxAge = int.tryParse(_newMaxAgeController.text.trim());

    if (name.isEmpty || minAge == null || maxAge == null) {
      CustomSnackbar.showError(
        context,
        'الرجاء إدخال جميع بيانات الفئة العمرية',
      );
      return;
    }

    if (minAge >= maxAge) {
      CustomSnackbar.showError(
        context,
        'العمر الأصغر يجب أن يكون أقل من العمر الأكبر',
      );
      return;
    }

    final specialtyIndex = _specialties.indexWhere((s) => s.id == specialtyId);
    if (specialtyIndex != -1) {
      setState(() {
        _specialties[specialtyIndex].ageCategories.add(
          AgeCategoryItem(name: name, minAge: minAge, maxAge: maxAge),
        );
        _newAgeCategoryController.clear();
        _newMinAgeController.clear();
        _newMaxAgeController.clear();
      });
    }
  }

  void _removeAgeCategory(int specialtyId, String categoryName) {
    final specialtyIndex = _specialties.indexWhere((s) => s.id == specialtyId);
    if (specialtyIndex != -1) {
      setState(() {
        _specialties[specialtyIndex].ageCategories.removeWhere(
          (c) => c.name == categoryName,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _monthlyFeeController.dispose();
    _insuranceFeeController.dispose();
    _sessionsPerWeekController.dispose();
    _newItemNameController.dispose();
    _newItemPriceController.dispose();
    _newMonthsController.dispose();
    _newDiscountController.dispose();
    _newSpecialtyController.dispose();
    _newAgeCategoryController.dispose();
    _newMinAgeController.dispose();
    _newMaxAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '💰 مالي', icon: Icon(Icons.attach_money)),
            Tab(text: '🛒 أدوات', icon: Icon(Icons.shopping_bag)),
            Tab(text: '🏷️ تخفيضات', icon: Icon(Icons.local_offer)),
            Tab(text: '🥋 رياضة', icon: Icon(Icons.sports_martial_arts)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب 1: الإعدادات المالية
          _buildFinancialTab(),

          // تبويب 2: الأدوات الرياضية
          _buildSportsItemsTab(),

          // تبويب 3: تخفيضات الدفع المسبق
          _buildDiscountsTab(),

          // تبويب 4: الاختصاصات والفئات العمرية
          _buildSportsSettingsTab(),
        ],
      ),
    );
  }

  // ==================== تبويب الإعدادات المالية ====================
  Widget _buildFinancialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'الإعدادات المالية الأساسية',
          icon: Icons.attach_money,
          children: [
            _buildTextField(
              'قيمة الاشتراك الشهري (دج)',
              _monthlyFeeController,
              Icons.calendar_today,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'حقوق التسجيل السنوية (دج)',
              _insuranceFeeController,
              Icons.security,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'عدد الحصص في الأسبوع',
              _sessionsPerWeekController,
              Icons.fitness_center,
            ),
          ],
        ),
      ],
    );
  }

  // ==================== تبويب الأدوات الرياضية ====================
  Widget _buildSportsItemsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'الأدوات الرياضية',
          icon: Icons.shopping_bag,
          children: [
            ..._sportsItems.map(
              (item) => ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.orange),
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
      ],
    );
  }

  // ==================== تبويب تخفيضات الدفع المسبق ====================
  Widget _buildDiscountsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'تخفيضات الدفع المسبق',
          icon: Icons.local_offer,
          children: [
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
            if (_discountPackages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا توجد تخفيضات مسجلة',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const Divider(),
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
      ],
    );
  }

  // ==================== تبويب الإعدادات الرياضية (للبطولات) ====================
  Widget _buildSportsSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'الاختصاصات والفئات العمرية',
          icon: Icons.sports_martial_arts,
          children: [
            ..._specialties.map(
              (specialty) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                    specialty.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeSpecialty(specialty.id),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الفئات العمرية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...specialty.ageCategories.map(
                            (category) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(category.name),
                                subtitle: Text(
                                  '${category.minAge} - ${category.maxAge} سنة',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _removeAgeCategory(
                                    specialty.id,
                                    category.name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (specialty.ageCategories.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'لا توجد فئات عمرية',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _newAgeCategoryController,
                                  decoration: const InputDecoration(
                                    hintText: 'اسم الفئة',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _newMinAgeController,
                                  decoration: const InputDecoration(
                                    hintText: 'من',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('إلى'),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _newMaxAgeController,
                                  decoration: const InputDecoration(
                                    hintText: 'إلى',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _addAgeCategory(specialty.id),
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSpecialtyController,
                    decoration: const InputDecoration(
                      hintText: 'اختصاص جديد (مثال: واكو حلبة)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addSpecialty,
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
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFE53935)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: TextInputType.number,
    );
  }
}

// ==================== نماذج البيانات ====================

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

class SpecialtyItem {
  int id;
  String name;
  List<AgeCategoryItem> ageCategories;

  SpecialtyItem({
    required this.id,
    required this.name,
    required this.ageCategories,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ageCategories': ageCategories.map((c) => c.toJson()).toList(),
    };
  }

  factory SpecialtyItem.fromJson(Map<String, dynamic> json) {
    return SpecialtyItem(
      id: json['id'],
      name: json['name'],
      ageCategories: (json['ageCategories'] as List)
          .map((c) => AgeCategoryItem.fromJson(c))
          .toList(),
    );
  }
}

class AgeCategoryItem {
  String name;
  int minAge;
  int maxAge;

  AgeCategoryItem({
    required this.name,
    required this.minAge,
    required this.maxAge,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'minAge': minAge, 'maxAge': maxAge};
  }

  factory AgeCategoryItem.fromJson(Map<String, dynamic> json) {
    return AgeCategoryItem(
      name: json['name'],
      minAge: json['minAge'],
      maxAge: json['maxAge'],
    );
  }
}
