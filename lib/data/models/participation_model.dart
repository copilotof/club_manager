// lib/data/models/participation_model.dart
import 'package:flutter/material.dart';

class ParticipationModel {
  final int? id;
  final int competitionId;
  final int studentId;
  final int specialtyId;
  final String ageCategory;
  final double weightCategory;
  final String result; // 'gold', 'silver', 'bronze', 'participation'
  final int? rank;
  final String? medalType;
  final String? notes;
  final DateTime createdAt;

  ParticipationModel({
    this.id,
    required this.competitionId,
    required this.studentId,
    required this.specialtyId,
    required this.ageCategory,
    required this.weightCategory,
    required this.result,
    this.rank,
    this.medalType,
    this.notes,
    required this.createdAt,
  });

  String get resultName {
    switch (result) {
      case 'gold':
        return '🥇 ذهبية';
      case 'silver':
        return '🥈 فضية';
      case 'bronze':
        return '🥉 برونزية';
      case 'participation':
        return '📋 مشاركة';
      default:
        return result;
    }
  }

  Color get resultColor {
    switch (result) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      case 'bronze':
        return Colors.brown;
      case 'participation':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'competition_id': competitionId,
      'student_id': studentId,
      'specialty_id': specialtyId,
      'age_category': ageCategory,
      'weight_category': weightCategory,
      'result': result,
      'rank': rank,
      'medal_type': medalType,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ParticipationModel.fromMap(Map<String, dynamic> map) {
    return ParticipationModel(
      id: map['id'],
      competitionId: map['competition_id'],
      studentId: map['student_id'],
      specialtyId: map['specialty_id'],
      ageCategory: map['age_category'],
      weightCategory: map['weight_category'].toDouble(),
      result: map['result'],
      rank: map['rank'],
      medalType: map['medal_type'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
