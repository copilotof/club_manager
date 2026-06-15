// lib/data/models/belt_model.dart
import 'package:flutter/material.dart';

class BeltModel {
  final int? id;
  final int studentId;
  final String beltColor;
  final DateTime dateAchieved;
  final String? coachName;
  final String? notes;
  final int orderIndex; // ترتيب الحزام (1 للأبيض، 2 للأصفر، ...)

  BeltModel({
    this.id,
    required this.studentId,
    required this.beltColor,
    required this.dateAchieved,
    this.coachName,
    this.notes,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'belt_color': beltColor,
      'date_achieved': dateAchieved.toIso8601String(),
      'coach_name': coachName,
      'notes': notes,
      'order_index': orderIndex,
    };
  }

  factory BeltModel.fromMap(Map<String, dynamic> map) {
    return BeltModel(
      id: map['id'],
      studentId: map['student_id'],
      beltColor: map['belt_color'],
      dateAchieved: DateTime.parse(map['date_achieved']),
      coachName: map['coach_name'],
      notes: map['notes'],
      orderIndex: map['order_index'],
    );
  }

  // الحصول على لون الخلفية للحزام
  Color getColor() {
    switch (beltColor.toLowerCase()) {
      case 'أبيض':
        return Colors.grey.shade100;
      case 'أصفر':
        return Colors.yellow.shade700;
      case 'برتقالي':
        return Colors.orange;
      case 'أخضر':
        return Colors.green;
      case 'أزرق':
        return Colors.blue;
      case 'بني':
        return Colors.brown;
      case 'أسود':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  // الحصول على لون النص المناسب
  Color getTextColor() {
    final color = getColor();
    // إذا كان اللون فاتحاً، استخدم نص داكن
    if (beltColor.toLowerCase() == 'أبيض' ||
        beltColor.toLowerCase() == 'أصفر') {
      return Colors.black87;
    }
    return Colors.white;
  }
}
