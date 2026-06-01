// lib/data/models/payment_model.dart
class PaymentModel {
  final int? id;
  final int studentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentType; // 'monthly', 'insurance', 'extra'
  final int? month; // الشهر (1-12) إذا كان paymentType = 'monthly'
  final int? year; // السنة
  final bool isExtra;
  final String? extraReason;
  final bool isGifted; // إذا كانت المستحقات الإضافية مُهداة
  final String? notes;

  PaymentModel({
    this.id,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentType,
    this.month,
    this.year,
    this.isExtra = false,
    this.extraReason,
    this.isGifted = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_type': paymentType,
      'month': month,
      'year': year,
      'is_extra': isExtra ? 1 : 0,
      'extra_reason': extraReason,
      'is_gifted': isGifted ? 1 : 0,
      'notes': notes,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'],
      studentId: map['student_id'],
      amount: map['amount'],
      paymentDate: DateTime.parse(map['payment_date']),
      paymentType: map['payment_type'],
      month: map['month'],
      year: map['year'],
      isExtra: map['is_extra'] == 1,
      extraReason: map['extra_reason'],
      isGifted: map['is_gifted'] == 1,
      notes: map['notes'],
    );
  }

  String get paymentTypeName {
    switch (paymentType) {
      case 'monthly':
        return 'اشتراك شهري';
      case 'insurance':
        return 'حقوق التأمين';
      case 'extra':
        return 'مستحقات إضافية';
      default:
        return paymentType;
    }
  }
}
