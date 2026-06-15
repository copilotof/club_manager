// lib/data/models/group_model.dart
class GroupModel {
  final int? id;
  final int hallId;
  final String name;
  final String? description;
  final int studentCount;

  GroupModel({
    this.id,
    required this.hallId,
    required this.name,
    this.description,
    this.studentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hall_id': hallId,
      'name': name,
      'description': description,
      'student_count': studentCount,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'],
      hallId: map['hall_id'],
      name: map['name'],
      description: map['description'],
      studentCount: map['student_count'],
    );
  }
}
