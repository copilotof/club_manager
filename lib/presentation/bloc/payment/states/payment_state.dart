// lib/presentation/bloc/payment/states/payment_state.dart
import 'package:equatable/equatable.dart';
import '../../../../data/models/payment_model.dart';

abstract class PaymentState extends Equatable {
  const PaymentState();
  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentsLoaded extends PaymentState {
  final List<PaymentModel> payments;
  final double totalIncome;
  final double totalOutstanding;
  const PaymentsLoaded({
    required this.payments,
    this.totalIncome = 0,
    this.totalOutstanding = 0,
  });
  @override
  List<Object?> get props => [payments, totalIncome, totalOutstanding];
}

class PaymentOperationSuccess extends PaymentState {
  final String message;
  const PaymentOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class PaymentError extends PaymentState {
  final String message;
  const PaymentError(this.message);
  @override
  List<Object?> get props => [message];
}
