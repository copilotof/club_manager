// lib/data/models/extra_session_model.dart
import 'package:flutter/material.dart';

class ExtraSessionModel {
  final int? id;
  final DateTime date;
  final int hallId;
  final int groupId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? reason;
  final DateTime createdAt;

  ExtraSessionModel({
    this.id,
    required this.date,
    required this.hallId,
    required this.groupId,
    required this.startTime,
    required this.endTime,
    this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'hall_id': hallId,
      'group_id': groupId,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExtraSessionModel.fromMap(Map<String, dynamic> map) {
    final startParts = map['start_time'].split(':');
    final endParts = map['end_time'].split(':');

    return ExtraSessionModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      hallId: map['hall_id'],
      groupId: map['group_id'],
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      reason: map['reason'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
