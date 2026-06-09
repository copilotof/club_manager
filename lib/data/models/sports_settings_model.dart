// lib/data/models/sports_settings_model.dart
class SportsSettingsModel {
  List<Specialty> specialties;

  SportsSettingsModel({required this.specialties});

  Map<String, dynamic> toMap() {
    return {'specialties': specialties.map((s) => s.toMap()).toList()};
  }

  factory SportsSettingsModel.fromMap(Map<String, dynamic> map) {
    return SportsSettingsModel(
      specialties: (map['specialties'] as List)
          .map((s) => Specialty.fromMap(s))
          .toList(),
    );
  }
}

class Specialty {
  int id;
  String name;
  List<AgeCategory> ageCategories;

  Specialty({
    required this.id,
    required this.name,
    required this.ageCategories,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age_categories': ageCategories.map((a) => a.toMap()).toList(),
    };
  }

  factory Specialty.fromMap(Map<String, dynamic> map) {
    return Specialty(
      id: map['id'],
      name: map['name'],
      ageCategories: (map['age_categories'] as List)
          .map((a) => AgeCategory.fromMap(a))
          .toList(),
    );
  }
}

class AgeCategory {
  String name;
  int minAge;
  int maxAge;
  List<WeightCategory> weightCategories;

  AgeCategory({
    required this.name,
    required this.minAge,
    required this.maxAge,
    required this.weightCategories,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'min_age': minAge,
      'max_age': maxAge,
      'weight_categories': weightCategories.map((w) => w.toMap()).toList(),
    };
  }

  factory AgeCategory.fromMap(Map<String, dynamic> map) {
    return AgeCategory(
      name: map['name'],
      minAge: map['min_age'],
      maxAge: map['max_age'],
      weightCategories: (map['weight_categories'] as List)
          .map((w) => WeightCategory.fromMap(w))
          .toList(),
    );
  }
}

class WeightCategory {
  String gender; // 'male', 'female'
  double weight;

  WeightCategory({required this.gender, required this.weight});

  Map<String, dynamic> toMap() {
    return {'gender': gender, 'weight': weight};
  }

  factory WeightCategory.fromMap(Map<String, dynamic> map) {
    return WeightCategory(
      gender: map['gender'],
      weight: map['weight'].toDouble(),
    );
  }
}
