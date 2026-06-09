// lib/data/models/specialty_model.dart
class SpecialtyModel {
  final int id;
  final String name;
  final List<AgeCategory> ageCategories;

  SpecialtyModel({
    required this.id,
    required this.name,
    required this.ageCategories,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  factory SpecialtyModel.fromMap(Map<String, dynamic> map) {
    return SpecialtyModel(id: map['id'], name: map['name'], ageCategories: []);
  }
}

class AgeCategory {
  final String name;
  final int minAge;
  final int maxAge;
  final Map<String, List<double>>
  weightCategories; // 'male' / 'female' -> [weights]

  AgeCategory({
    required this.name,
    required this.minAge,
    required this.maxAge,
    required this.weightCategories,
  });

  bool isAgeInRange(int age) {
    return age >= minAge && age <= maxAge;
  }

  List<double> getWeightsByGender(String gender) {
    return weightCategories[gender] ?? [];
  }
}
