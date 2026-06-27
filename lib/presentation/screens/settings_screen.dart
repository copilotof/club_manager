// lib/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/widgets/custom_snackbar.dart';
import '../../data/models/group_model.dart';
import '../../data/models/hall_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/hall_repository.dart';
import '../../injection/dependency_injection.dart';

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

  // المتغيرات المستخدمة في التبويب
  List<HallModel> _halls = []; // قائمة القاعات
  int? _selectedHallId; // القاعة المختارة حالياً
  List<GroupModel> _groups = []; // قائمة الأفواج في القاعة المختارة
  List<SessionModel> _sessions = []; // قائمة الحصص للفوج المختار
  int? _selectedGroupId; // الفوج المختار حالياً

// متغيرات إعدادات التنبيهات
  final _recurrentAbsenceController = TextEditingController();
  final _competitionReminderController = TextEditingController();
  final _beltPromotionController = TextEditingController();
  final _paymentDelayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
    _loadHalls(); // ✅ تحميل القاعات عند بدء الشاشة
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

      // ✅ إعدادات التنبيهات
      _recurrentAbsenceController.text =
          prefs.getInt('recurrent_absence_threshold')?.toString() ?? '3';
      _competitionReminderController.text =
          prefs.getInt('competition_reminder_days')?.toString() ?? '7';
      _beltPromotionController.text =
          prefs.getInt('belt_promotion_months')?.toString() ?? '3';
      _paymentDelayController.text =
          prefs.getInt('payment_delay_months')?.toString() ?? '2';

      // الاختصاصات الرياضية
      final specialtiesJson = prefs.getString('sports_specialties');
      if (specialtiesJson != null && specialtiesJson.isNotEmpty) {
        final List<dynamic> data = jsonDecode(specialtiesJson);
        _specialties = data.map((s) => SpecialtyItem.fromJson(s)).toList();
      } else {
        // بيانات افتراضية
        _specialties = [
          /*      SpecialtyItem(
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
          ), */
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
          'monthly_fee', double.parse(_monthlyFeeController.text));
      await prefs.setDouble(
          'insurance_fee', double.parse(_insuranceFeeController.text));
      await prefs.setInt(
          'sessions_per_week', int.parse(_sessionsPerWeekController.text));
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
            Tab(text: '🏢 تنظيمي', icon: Icon(Icons.business)), // ✅ تبويب جديد
            Tab(
                text: '🔔 تنبيهات',
                icon: Icon(Icons.notifications_active)), // ✅ جديد
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'حفظ',
          ),
          Text("حفظ الجميع"),
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

          _buildOrganizationalTab(), // ✅ تبويب القاعات والأفواج

          _buildNotificationsTab(), // ✅ إضافة التبويب الجديد
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
/*             const SizedBox(height: 12),
            _buildTextField(
              'عدد الحصص في الأسبوع',
              _sessionsPerWeekController,
              Icons.fitness_center,
            ), */
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSectionCard(
        title: 'الاختصاصات والفئات',
        icon: Icons.sports_martial_arts,
        children: [
          ..._specialties.map((specialty) => Card(
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
                          const Text('الفئات العمرية',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...specialty.ageCategories.map((category) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(category.name),
                                  subtitle: Text(
                                      '${category.minAge} - ${category.maxAge} سنة'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    onPressed: () => _removeAgeCategory(
                                        specialty.id, category.name),
                                  ),
                                ),
                              )),
                          if (specialty.ageCategories.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('لا توجد فئات عمرية',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          const SizedBox(height: 8),
                          // ✅ Row معدلة لمنع التجاوز
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // حقل اسم الفئة
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _newAgeCategoryController,
                                  decoration: const InputDecoration(
                                    hintText: 'اسم الفئة',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              // حقل العمر من
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: _newMinAgeController,
                                  decoration: const InputDecoration(
                                    hintText: 'من',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const Text('إلى', style: TextStyle(fontSize: 12)),
                              // حقل العمر إلى
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: _newMaxAgeController,
                                  decoration: const InputDecoration(
                                    hintText: 'إلى',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              // زر الإضافة
                              IconButton(
                                onPressed: () => _addAgeCategory(specialty.id),
                                icon: const Icon(Icons.add_circle,
                                    color: Colors.green),
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                iconSize: 28,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
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
                icon: const Icon(Icons.add_circle,
                    color: Color(0xFFE53935), size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ==================== تبويب إعدادات التنبيهات ====================
  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'إعدادات التنبيهات',
          icon: Icons.notifications_active,
          children: [
            // 1. تنبيه الغياب المتكرر
            _buildNotificationSetting(
              title: 'تنبيه الغياب المتكرر',
              description: 'عدد الغيابات المتتالية التي تستدعي التنبيه',
              controller: _recurrentAbsenceController,
              hint: '3',
              icon: Icons.warning_amber,
            ),
            const Divider(),

            // 2. تنبيه البطولات القادمة
            _buildNotificationSetting(
              title: 'تنبيه البطولات القادمة',
              description: 'عدد الأيام قبل البطولة لإرسال التنبيه',
              controller: _competitionReminderController,
              hint: '7',
              icon: Icons.emoji_events,
            ),
            const Divider(),

            // 3. تنبيه ترقية الحزام
            _buildNotificationSetting(
              title: 'تنبيه ترقية الحزام',
              description: 'عدد الأشهر بين كل ترقية (للتنبيه)',
              controller: _beltPromotionController,
              hint: '3',
              icon: Icons.sports_martial_arts,
            ),
            const Divider(),

            // 4. تنبيه تأخر الدفع
            _buildNotificationSetting(
              title: 'تنبيه تأخر الدفع',
              description: 'عدد أشهر التأخر في الدفع للتنبيه',
              controller: _paymentDelayController,
              hint: '2',
              icon: Icons.payments,
            ),

            const SizedBox(height: 16),

            // زر حفظ إعدادات التنبيهات
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('حفظ الإعدادات',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

// ==================== عنصر إعداد التنبيه ====================
  Widget _buildNotificationSetting({
    required String title,
    required String description,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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

  // ==================== تبويب التنظيم (القاعات والأفواج) ====================

  // دوال تحميل البيانات من قاعدة البيانات
  Future<void> _loadHalls() async {
    final repo = HallRepository(localDb: getIt());
    _halls = await repo.getAllHalls();
    setState(() {});
  }

  Future<void> _loadGroups(int hallId) async {
    final repo = GroupRepository(localDb: getIt());
    _groups = await repo.getGroupsByHall(hallId);
    setState(() {});
  }

  Future<void> _loadSessions(int groupId) async {
    final repo = GroupRepository(localDb: getIt());
    _sessions = await repo.getSessionsByGroup(groupId);
    setState(() {});
  }

  // ==================== دوال إدارة القاعات ====================

  // إضافة قاعة جديدة
  // إضافة قاعة جديدة
  Future<void> _addHall() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ إضافة قاعة جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم القاعة *',
                  hintText: 'مثال: القاعة الرئيسية',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  hintText: 'مثال: شارع الرياضة',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  hintText: 'مثال: 0555123456',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                CustomSnackbar.showError(context, 'اسم القاعة مطلوب');
                return;
              }
              final hall = HallModel(
                name: nameController.text.trim(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              );
              final repo = HallRepository(localDb: getIt());
              await repo.addHall(hall);
              await _loadHalls(); // ✅ إعادة تحميل القاعات
              setState(() {}); // ✅ تحديث الواجهة
              if (mounted) Navigator.pop(context);
              CustomSnackbar.showSuccess(context, '✅ تم إضافة القاعة');
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // تعديل قاعة
  Future<void> _editHall(HallModel hall) async {
    final nameController = TextEditingController(text: hall.name);
    final addressController = TextEditingController(text: hall.address ?? '');
    final phoneController = TextEditingController(text: hall.phone ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ تعديل القاعة'),
        content: SingleChildScrollView(
          // ✅ لف المحتوى بـ SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم القاعة *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                CustomSnackbar.showError(context, 'اسم القاعة مطلوب');
                return;
              }
              final updatedHall = HallModel(
                id: hall.id,
                name: nameController.text.trim(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              );
              final repo = HallRepository(localDb: getIt());
              await repo.updateHall(updatedHall);
              await _loadHalls();
              setState(() {}); // ✅ تحديث الواجهة
              if (mounted) Navigator.pop(context);
              CustomSnackbar.showSuccess(context, '✅ تم تحديث القاعة');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // حذف قاعة
  Future<void> _deleteHall(int id, String name) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف قاعة "$name"؟\nسيتم حذف جميع الأفواج والحصص المرتبطة بها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = HallRepository(localDb: getIt());
      await repo.deleteHall(id);
      await _loadHalls();
      setState(() {}); // ✅ تحديث الواجهة
      if (_selectedHallId == id) {
        setState(() {
          _selectedHallId = null;
          _groups = [];
          _selectedGroupId = null;
          _sessions = [];
        });
      }
      CustomSnackbar.showSuccess(context, '✅ تم حذف القاعة');
    }
  }

  // ==================== دوال إدارة الأفواج ====================

  // إضافة فوج جديد
  // إضافة فوج جديد
  Future<void> _addGroup(int hallId) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ إضافة فوج جديد'),
        content: SingleChildScrollView(
          // ✅ لف المحتوى بـ SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفوج *',
                  hintText: 'مثال: فوج المبتدئين',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف (اختياري)',
                  hintText: 'مثال: المستوى الأول',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                CustomSnackbar.showError(context, 'اسم الفوج مطلوب');
                return;
              }
              final group = GroupModel(
                hallId: hallId,
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              );
              final repo = GroupRepository(localDb: getIt());
              await repo.addGroup(group);
              await _loadGroups(hallId);
              if (mounted) Navigator.pop(context);
              CustomSnackbar.showSuccess(context, '✅ تم إضافة الفوج');
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // تعديل فوج
  Future<void> _editGroup(GroupModel group) async {
    final nameController = TextEditingController(text: group.name);
    final descriptionController = TextEditingController(
      text: group.description ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ تعديل الفوج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم الفوج *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                CustomSnackbar.showError(context, 'اسم الفوج مطلوب');
                return;
              }
              final updatedGroup = GroupModel(
                id: group.id,
                hallId: group.hallId,
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              );
              final repo = GroupRepository(localDb: getIt());
              await repo.updateGroup(updatedGroup);
              await _loadGroups(group.hallId);
              if (mounted) Navigator.pop(context);
              CustomSnackbar.showSuccess(context, '✅ تم تحديث الفوج');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // حذف فوج
  Future<void> _deleteGroup(int id, String name) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف فوج "$name"؟\nسيتم حذف جميع الحصص المرتبطة به.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = GroupRepository(localDb: getIt());
      await repo.deleteGroup(id);
      await _loadGroups(_selectedHallId!);
      if (_selectedGroupId == id) {
        setState(() {
          _selectedGroupId = null;
          _sessions = [];
        });
      }
      CustomSnackbar.showSuccess(context, '✅ تم حذف الفوج');
    }
  }

  // ==================== دوال إدارة الحصص التدريبية ====================

  // قائمة أيام الأسبوع
  final List<String> _weekDays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  // إضافة حصة تدريبية جديدة
  Future<void> _addSession(int groupId) async {
    int selectedDay = 0;
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 30);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('➕ إضافة حصة تدريبية'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // اختيار اليوم
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'اليوم *'),
                  items: _weekDays.asMap().entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedDay = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // اختيار وقت البداية
                ListTile(
                  title: const Text('وقت البداية'),
                  subtitle: Text(
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: true,
                          ), // ✅ تنسيق 24 ساعة
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        startTime = picked;
                      });
                    }
                  },
                ),
                // اختيار وقت النهاية (نفس الشيء)
                ListTile(
                  title: const Text('وقت النهاية'),
                  subtitle: Text(
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: true,
                          ), // ✅ تنسيق 24 ساعة
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        endTime = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () async {
                  final session = SessionModel(
                    groupId: groupId,
                    dayOfWeek: selectedDay,
                    startTime: startTime,
                    endTime: endTime,
                  );
                  final repo = GroupRepository(localDb: getIt());
                  await repo.addSession(session);
                  await _loadSessions(groupId);
                  if (mounted) Navigator.pop(context);
                  CustomSnackbar.showSuccess(context, '✅ تم إضافة الحصة');
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  // حذف حصة تدريبية
  Future<void> _deleteSession(int id) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الحصة التدريبية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = GroupRepository(localDb: getIt());
      await repo.deleteSession(id);
      await _loadSessions(_selectedGroupId!);
      CustomSnackbar.showSuccess(context, '✅ تم حذف الحصة');
    }
  }

  // ==================== واجهة تبويب التنظيم ====================

  Widget _buildOrganizationalTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadHalls(); // ✅ إعادة تحميل عند السحب للأسفل
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Row(
              children: [
                const Icon(Icons.business, color: Color(0xFFE53935), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'القاعات الرياضية',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // زر إضافة قاعة
                FloatingActionButton.small(
                  onPressed: _addHall,
                  backgroundColor: const Color(0xFFE53935),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // قائمة القاعات
            if (_halls.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد قاعات',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط على زر + لإضافة قاعة جديدة',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _halls.length,
                itemBuilder: (context, index) {
                  final hall = _halls[index];
                  return _buildHallCard(hall);
                },
              ),
          ],
        ),
      ),
    );
  }

  // بطاقة القاعة (مصممة بشكل أفضل)
  Widget _buildHallCard(HallModel hall) {
    final isExpanded = _selectedHallId == hall.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // رأس البطاقة
          InkWell(
            onTap: () {
              setState(() {
                if (_selectedHallId == hall.id) {
                  _selectedHallId = null;
                  _groups = [];
                } else {
                  _selectedHallId = hall.id;
                  _loadGroups(hall.id!);
                }
              });
              setState(() {}); // ✅ تحديث الواجهة
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // أيقونة القاعة
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.business,
                      color: Color(0xFFE53935),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // معلومات القاعة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hall.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hall.address != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hall.address!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hall.phone != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hall.phone!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // أزرار التحكم
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: () => _editHall(hall),
                        tooltip: 'تعديل القاعة',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 20,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteHall(hall.id!, hall.name),
                        tooltip: 'حذف القاعة',
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // المحتوى الموسع (الأفواج)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان الأفواج مع زر الإضافة
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'الأفواج',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _addGroup(hall.id!),
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: 'إضافة فوج',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // قائمة الأفواج
                  if (_groups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: Text(
                        'لا توجد أفواج. اضغط على + لإضافة فوج.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    )
                  else
                    ..._groups.map((group) => _buildGroupCard(group)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // بطاقة الفوج (مصممة بشكل أفضل)
  Widget _buildGroupCard(GroupModel group) {
    final isExpanded = _selectedGroupId == group.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // رأس بطاقة الفوج
          InkWell(
            onTap: () {
              setState(() {
                if (_selectedGroupId == group.id) {
                  _selectedGroupId = null;
                  _sessions = [];
                } else {
                  _selectedGroupId = group.id;
                  _loadSessions(group.id!);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.group,
                      color: Colors.green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (group.description != null)
                          Text(
                            group.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed: () => _editGroup(group),
                        tooltip: 'تعديل الفوج',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteGroup(group.id!, group.name),
                        tooltip: 'حذف الفوج',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // المحتوى الموسع (الحصص)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان الحصص مع زر الإضافة
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'الحصص التدريبية',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _addSession(group.id!),
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.orange,
                        ),
                        tooltip: 'إضافة حصة',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // قائمة الحصص
                  if (_sessions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.center,
                      child: Text(
                        'لا توجد حصص تدريبية. اضغط على + لإضافة حصة.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    )
                  else
                    ..._sessions.map((session) => _buildSessionCard(session)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // بطاقة الحصة التدريبية (تنسيق 24 ساعة)
  Widget _buildSessionCard(SessionModel session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // أيقونة اليوم
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                session.dayName.substring(0, 2),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // معلومات الوقت (بصيغة 24 ساعة)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')} - '
                  '${session.endTime.hour.toString().padLeft(2, '0')}:${session.endTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          // زر الحذف
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _deleteSession(session.id!),
            tooltip: 'حذف الحصة',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // بناء بطاقة الفوج (داخل القاعة)
  Widget _buildGroupTile(GroupModel group) {
    final isSelected = _selectedGroupId == group.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.grey.shade50 : null,
      child: ExpansionTile(
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: group.description != null ? Text(group.description!) : null,
        leading: const Icon(Icons.group, color: Colors.green),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _editGroup(group),
              tooltip: 'تعديل الفوج',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteGroup(group.id!, group.name),
              tooltip: 'حذف الفوج',
            ),
          ],
        ),
        children: [
          // ==================== قسم الحصص التدريبية ====================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان الحصص مع زر الإضافة
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'الحصص التدريبية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _addSession(group.id!),
                      icon: const Icon(Icons.add_circle, color: Colors.orange),
                      tooltip: 'إضافة حصة',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // قائمة الحصص
                if (_selectedGroupId != group.id)
                  FutureBuilder<List<SessionModel>>(
                    future: GroupRepository(
                      localDb: getIt(),
                    ).getSessionsByGroup(group.id!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final sessions = snapshot.data!;
                      if (sessions.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'لا توجد حصص تدريبية. اضغط على + لإضافة حصة.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return Column(
                        children: sessions
                            .map((session) => _buildSessionTile(session))
                            .toList(),
                      );
                    },
                  )
                else
                  Column(
                    children: _sessions
                        .map((session) => _buildSessionTile(session))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
        onExpansionChanged: (expanded) {
          if (expanded) {
            setState(() {
              _selectedGroupId = group.id;
            });
            _loadSessions(group.id!);
          } else {
            if (_selectedGroupId == group.id) {
              setState(() {
                _selectedGroupId = null;
                _sessions = [];
              });
            }
          }
        },
      ),
    );
  }

  // بناء بطاقة الحصة التدريبية
  Widget _buildSessionTile(SessionModel session) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.orange.shade100,
        child: Text(
          session.dayName.substring(0, 2),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(session.dayName),
      subtitle: Text(
        '${session.startTime.format(context)} - ${session.endTime.format(context)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
        onPressed: () => _deleteSession(session.id!),
        tooltip: 'حذف الحصة',
      ),
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
