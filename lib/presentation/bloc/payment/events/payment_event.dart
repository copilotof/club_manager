// lib/presentation/bloc/payment/events/payment_event.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/payment_model.dart';

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();
  @override
  List<Object?> get props => [];
}

// تحميل جميع الدفعات
class LoadPaymentsEvent extends PaymentEvent {}

// تحميل دفعات طالب معين
class LoadStudentPaymentsEvent extends PaymentEvent {
  final int studentId;
  const LoadStudentPaymentsEvent(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

// إضافة دفعة جديدة
class AddPaymentEvent extends PaymentEvent {
  final PaymentModel payment;
  const AddPaymentEvent(this.payment);
  @override
  List<Object?> get props => [payment];
}

// حذف دفعة
class DeletePaymentEvent extends PaymentEvent {
  final int paymentId;
  const DeletePaymentEvent(this.paymentId);
  @override
  List<Object?> get props => [paymentId];
}
