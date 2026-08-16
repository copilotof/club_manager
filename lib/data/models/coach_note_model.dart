// lib/data/models/coach_note_model.dart
class CoachNoteModel {
  final int? id;
  final int sessionId; // معرف الحصة التدريبية
  final DateTime sessionDate;
  final String? title;
  final List<NotePart> parts;
  final String? generalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CoachNoteModel({
    this.id,
    required this.sessionId,
    required this.sessionDate,
    this.title,
    required this.parts,
    this.generalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'session_date': sessionDate.toIso8601String(),
      'title': title,
      'parts': parts.map((p) => p.toMap()).toList(),
      'general_notes': generalNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CoachNoteModel.fromMap(Map<String, dynamic> map) {
    return CoachNoteModel(
      id: map['id'],
      sessionId: map['session_id'],
      sessionDate: DateTime.parse(map['session_date']),
      title: map['title'],
      parts: (map['parts'] as List).map((p) => NotePart.fromMap(p)).toList(),
      generalNotes: map['general_notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class NotePart {
  final int id;
  final String name;
  final int minutes; // ✅ تغيير من percentage إلى minutes
  final String? description;

  NotePart({
    required this.id,
    required this.name,
    required this.minutes,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'minutes': minutes, // ✅ تغيير
      'description': description,
    };
  }

  factory NotePart.fromMap(Map<String, dynamic> map) {
    return NotePart(
      id: map['id'],
      name: map['name'],
      minutes: map['minutes'].toInt(),
      description: map['description'],
    );
  }
}
