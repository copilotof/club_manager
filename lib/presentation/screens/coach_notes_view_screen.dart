// lib/presentation/screens/coach_notes_view_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/coach_note_model.dart';

class CoachNotesViewScreen extends StatelessWidget {
  final CoachNoteModel note;

  const CoachNotesViewScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    // ✅ تنسيق التاريخ بشكل صحيح
    final formattedDate =
        DateFormat('yyyy/MM/dd', 'en_US').format(note.sessionDate);
    final dayName = _getDayName(note.sessionDate.weekday);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ملاحظات المدرب'),
            Text(
              '$dayName - $formattedDate',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            if (note.title != null) ...[
              Text(
                note.title!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // توزيع الحصة (نسب مئوية)
            const Text(
              'توزيع الحصة التدريبية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...note.parts.map((part) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              part.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${part.minutes.toStringAsFixed(0)} دقيقة',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (part.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          part.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      // شريط التقدم
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: part.minutes / 100,
                          backgroundColor: Colors.grey[200],
                          color: const Color(0xFFE53935),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // ملاحظات عامة
            if (note.generalNotes != null) ...[
              const Text(
                'ملاحظات عامة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  note.generalNotes!,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    return days[weekday == 7 ? 0 : weekday];
  }
}
