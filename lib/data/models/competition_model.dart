// lib/data/models/competition_model.dart
import 'package:flutter/material.dart';

class CompetitionModel {
  final int? id;
  final String name;
  final String type; // 'regional', 'national', 'international'
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final List<int> specialtyIds;
  final List<String> ageCategories;
  final String? notes;

  CompetitionModel({
    this.id,
    required this.name,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.specialtyIds,
    required this.ageCategories,
    this.notes,
  });

  String get typeName {
    switch (type) {
      case 'regional':
        return 'ولائية';
      case 'national':
        return 'وطنية';
      case 'international':
        return 'دولية';
      default:
        return type;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'regional':
        return Colors.blue;
      case 'national':
        return Colors.green;
      case 'international':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'specialty_ids': specialtyIds.join(','),
      'age_categories': ageCategories.join(','),
      'notes': notes,
    };
  }

  factory CompetitionModel.fromMap(Map<String, dynamic> map) {
    return CompetitionModel(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      location: map['location'],
      specialtyIds: (map['specialty_ids'] as String)
          .split(',')
          .map(int.parse)
          .toList(),
      ageCategories: (map['age_categories'] as String).split(','),
      notes: map['notes'],
    );
  }
}
