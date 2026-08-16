// lib/data/models/payment_model.dart
class PaymentModel {
  final int? id;
  final int studentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentType; // 'monthly', 'insurance', 'extra'
  final int? month;
  final int? year;
  final bool isExtra;
  final String? extraReason;
  final bool isGifted;
  final String? notes;

  final int? prepaidMonths; // عدد الأشهر المدفوعة مسبقاً
  final int? prepaidStartMonth; // شهر البداية للدفعة المسبقة
  final int? prepaidEndMonth; // شهر النهاية للدفعة المسبقة
// أضف هذه الحقول في PaymentModel
  final bool? isExtraCompleted; // هل المستحقات الإضافية مكتملة؟
  final double? extraTotalAmount; // المبلغ الإجمالي للمستحقات الإضافية

  // الحقول الجديدة
  final bool isPartial;
  final int? parentPaymentId;
  final int? discountMonths;
  final double? discountPercentage;
  final bool isFullyPaid;
  final int? targetMonth; // الشهر المستهدف (للاشتراك الشهري)
  final int? targetYear; // السنة المستهدفة (للتأمين)
  final double? remainingAmount;

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
    this.isPartial = false,
    this.isExtraCompleted = false,
    this.extraTotalAmount,
    this.parentPaymentId,
    this.discountMonths,
    this.discountPercentage,
    this.isFullyPaid = false,
    this.targetMonth,
    this.targetYear,
    this.remainingAmount,
    this.prepaidMonths,
    this.prepaidStartMonth,
    this.prepaidEndMonth,
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
      'is_partial': isPartial ? 1 : 0,
      'parent_payment_id': parentPaymentId,
      'discount_months': discountMonths,
      'discount_percentage': discountPercentage,
      'is_fully_paid': isFullyPaid ? 1 : 0,
      'target_month': targetMonth,
      'target_year': targetYear,
      'remaining_amount': remainingAmount,
      'prepaid_months': prepaidMonths,
      'prepaid_start_month': prepaidStartMonth,
      'prepaid_end_month': prepaidEndMonth,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'],
      studentId: map['student_id'],
      amount: map['amount'].toDouble(),
      paymentDate: DateTime.parse(map['payment_date']),
      paymentType: map['payment_type'],
      month: map['month'],
      year: map['year'],
      isExtra: map['is_extra'] == 1,
      extraReason: map['extra_reason'],
      isGifted: map['is_gifted'] == 1,
      notes: map['notes'],
      isPartial: map['is_partial'] == 1,
      parentPaymentId: map['parent_payment_id'],
      discountMonths: map['discount_months'],
      discountPercentage: map['discount_percentage']?.toDouble(),
      isFullyPaid: map['is_fully_paid'] == 1,
      targetMonth: map['target_month'],
      targetYear: map['target_year'],
      remainingAmount: map['remaining_amount']?.toDouble(),
      prepaidMonths: map['prepaid_months'],
      prepaidStartMonth: map['prepaid_start_month'],
      prepaidEndMonth: map['prepaid_end_month'],
    );
  }

  // دالة للحصول على اسم العرض للدفعة
  String get displayName {
    if (paymentType == 'monthly') {
      return 'اشتراك شهر ${targetMonth ?? month}';
    } else if (paymentType == 'insurance') {
      return 'حقوق التأمين ${targetYear ?? year}';
    } else if (paymentType == 'extra') {
      return extraReason ?? 'مستحقات إضافية';
    }
    return paymentType;
  }

  // دالة للحصول على المبلغ المطلوب كاملاً (من الإعدادات)
  double get requiredAmount {
    if (paymentType == 'monthly') {
      // سيتم جلب من الإعدادات
      return 2000;
    } else if (paymentType == 'insurance') {
      return 1000;
    }
    return amount;
  }

  // هل المبلغ مكتمل؟
  bool get isAmountComplete {
    if (remainingAmount != null) {
      return remainingAmount! <= 0;
    }
    return isFullyPaid;
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
