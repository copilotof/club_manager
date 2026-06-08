// lib/data/models/settings_model.dart
class SettingsModel {
  double monthlyFee; // قيمة الاشتراك الشهري
  double insuranceFee; // حقوق التسجيل (التأمين) السنوي
  int sessionsPerWeek; // عدد الحصص في الأسبوع
  List<SportsItem> sportsItems; // قائمة الأدوات الرياضية
  List<DiscountPackage> discountPackages; // تخفيضات الدفع المسبق

  SettingsModel({
    this.monthlyFee = 2000,
    this.insuranceFee = 1000,
    this.sessionsPerWeek = 3,
    List<SportsItem>? sportsItems,
    List<DiscountPackage>? discountPackages,
  }) : sportsItems = sportsItems ?? [],
       discountPackages = discountPackages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'monthly_fee': monthlyFee,
      'insurance_fee': insuranceFee,
      'sessions_per_week': sessionsPerWeek,
      'sports_items': sportsItems.map((e) => e.toMap()).toList(),
      'discount_packages': discountPackages.map((e) => e.toMap()).toList(),
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      monthlyFee: map['monthly_fee']?.toDouble() ?? 2000,
      insuranceFee: map['insurance_fee']?.toDouble() ?? 1000,
      sessionsPerWeek: map['sessions_per_week'] ?? 3,
      sportsItems:
          (map['sports_items'] as List?)
              ?.map((e) => SportsItem.fromMap(e))
              .toList() ??
          [],
      discountPackages:
          (map['discount_packages'] as List?)
              ?.map((e) => DiscountPackage.fromMap(e))
              .toList() ??
          [],
    );
  }
}

class SportsItem {
  int id;
  String name;
  double price;

  SportsItem({required this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price};
  }

  factory SportsItem.fromMap(Map<String, dynamic> map) {
    return SportsItem(
      id: map['id'],
      name: map['name'],
      price: map['price'].toDouble(),
    );
  }
}

class DiscountPackage {
  int months; // عدد الأشهر (3 أو 6)
  double discount; // نسبة التخفيض (مثلاً 10 يعني 10%)

  DiscountPackage({required this.months, required this.discount});

  Map<String, dynamic> toMap() {
    return {'months': months, 'discount': discount};
  }

  factory DiscountPackage.fromMap(Map<String, dynamic> map) {
    return DiscountPackage(
      months: map['months'],
      discount: map['discount'].toDouble(),
    );
  }
}
