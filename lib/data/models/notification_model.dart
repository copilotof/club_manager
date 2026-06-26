// lib/data/models/notification_model.dart

/// نموذج الإشعار - يمثل تنبيهاً أو إشعاراً في النظام
class NotificationModel {
  final int? id;
  final String
      type; // 'payment', 'attendance', 'competition', 'belt', 'general'
  final String title;
  final String message;
  final int? studentId; // معرف الطالب المرتبط (إذا كان الإشعار لطالب معين)
  final int? relatedId; // معرف العنصر المرتبط (دفعة، حصة، بطولة، إلخ)
  final bool isRead;
  final DateTime createdAt;
  final String? targetAudience; // 'admin', 'parent', 'student'
  final int priority; // 0=عادي, 1=مهم, 2=عاجل
  final String? actionUrl; // رابط للانتقال إلى الصفحة المناسبة

  NotificationModel({
    this.id,
    required this.type,
    required this.title,
    required this.message,
    this.studentId,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
    this.targetAudience,
    this.priority = 0,
    this.actionUrl,
  });

  /// تحويل الكائن إلى Map للتخزين في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'student_id': studentId,
      'related_id': relatedId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'target_audience': targetAudience,
      'priority': priority,
      'action_url': actionUrl,
    };
  }

  /// إنشاء كائن من Map (قراءة من قاعدة البيانات)
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      type: map['type'],
      title: map['title'],
      message: map['message'],
      studentId: map['student_id'],
      relatedId: map['related_id'],
      isRead: map['is_read'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      targetAudience: map['target_audience'],
      priority: map['priority'],
      actionUrl: map['action_url'],
    );
  }

  /// الحصول على اسم النوع بالعربية
  String get typeName {
    switch (type) {
      case 'payment':
        return 'دفعة مالية';
      case 'attendance':
        return 'حضور وغياب';
      case 'competition':
        return 'بطولة';
      case 'belt':
        return 'ترقية حزام';
      case 'general':
        return 'عام';
      default:
        return type;
    }
  }

  /// الحصول على أيقونة النوع
  String get typeIcon {
    switch (type) {
      case 'payment':
        return '💰';
      case 'attendance':
        return '📅';
      case 'competition':
        return '🏆';
      case 'belt':
        return '🥋';
      case 'general':
        return '📝';
      default:
        return '🔔';
    }
  }

  /// الحصول على لون النوع
  String get typeColor {
    switch (type) {
      case 'payment':
        return 'green';
      case 'attendance':
        return 'orange';
      case 'competition':
        return 'purple';
      case 'belt':
        return 'blue';
      case 'general':
        return 'grey';
      default:
        return 'grey';
    }
  }
}
