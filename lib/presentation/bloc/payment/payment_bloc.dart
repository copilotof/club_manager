// lib/presentation/bloc/payment/payment_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'events/payment_event.dart';
import 'states/payment_state.dart';
import '../../../domain/repositories/i_payment_repository.dart';
import '../../../data/models/payment_model.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final IPaymentRepository _repository;

  PaymentBloc(this._repository) : super(PaymentInitial()) {
    on<LoadPaymentsEvent>(_onLoadPayments);
    on<LoadStudentPaymentsEvent>(_onLoadStudentPayments);
    on<AddPaymentEvent>(_onAddPayment);
    on<DeletePaymentEvent>(_onDeletePayment);
  }

  Future<void> _onLoadPayments(
    LoadPaymentsEvent event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final payments = await _repository.getAllPayments();
      final totalIncome = await _repository.getTotalIncome();
      final totalOutstanding = await _repository.getTotalOutstanding();
      emit(
        PaymentsLoaded(
          payments: payments,
          totalIncome: totalIncome,
          totalOutstanding: totalOutstanding,
        ),
      );
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onLoadStudentPayments(
    LoadStudentPaymentsEvent event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final payments = await _repository.getStudentPayments(event.studentId);
      emit(PaymentsLoaded(payments: payments));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onAddPayment(
    AddPaymentEvent event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      await _repository.addPayment(event.payment);
      emit(const PaymentOperationSuccess('تم تسجيل الدفعة بنجاح'));
      add(LoadPaymentsEvent());
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onDeletePayment(
    DeletePaymentEvent event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      await _repository.deletePayment(event.paymentId);
      emit(const PaymentOperationSuccess('تم حذف الدفعة بنجاح'));
      add(LoadPaymentsEvent());
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }
}
