// lib/data/models/session_model.dart
import 'package:flutter/material.dart';

class SessionModel {
  final int? id;
  final int groupId;
  final int dayOfWeek; // 0=الأحد, 1=الإثنين, ..., 6=السبت
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  SessionModel({
    this.id,
    required this.groupId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  String get dayName {
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    return days[dayOfWeek];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'day_of_week': dayOfWeek,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final startParts = map['start_time'].split(':');
    final endParts = map['end_time'].split(':');

    return SessionModel(
      id: map['id'],
      groupId: map['group_id'],
      dayOfWeek: map['day_of_week'],
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
    );
  }
}
