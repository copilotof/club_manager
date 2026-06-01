// lib/domain/repositories/i_payment_repository.dart
import '../../data/models/payment_model.dart';

abstract class IPaymentRepository {
  Future<List<PaymentModel>> getAllPayments();
  Future<List<PaymentModel>> getStudentPayments(int studentId);
  Future<void> addPayment(PaymentModel payment);
  Future<void> deletePayment(int paymentId);
  Future<double> getTotalIncome();
  Future<double> getTotalOutstanding();
}
