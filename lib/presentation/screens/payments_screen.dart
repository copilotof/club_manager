// lib/presentation/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/payment_model.dart';
import '../bloc/payment/payment_bloc.dart';
import '../bloc/payment/events/payment_event.dart';
import '../bloc/payment/states/payment_state.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../injection/dependency_injection.dart';
import 'add_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final int? studentId;
  const PaymentsScreen({super.key, this.studentId});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late PaymentBloc _paymentBloc;

  @override
  void initState() {
    super.initState();
    _paymentBloc = PaymentBloc(getIt());
    if (widget.studentId != null) {
      _paymentBloc.add(LoadStudentPaymentsEvent(widget.studentId!));
    } else {
      _paymentBloc.add(LoadPaymentsEvent());
    }
  }

  @override
  void dispose() {
    _paymentBloc.close();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  /*
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentId != null ? 'دفعات الطالب' : 'الدفعات المالية',
        ),
      ),
      body: BlocConsumer<PaymentBloc, PaymentState>(
        bloc: _paymentBloc,
        listener: (context, state) {
          if (state is PaymentOperationSuccess) {
            CustomSnackbar.showSuccess(context, state.message);
          }
          if (state is PaymentError) {
            CustomSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is PaymentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PaymentsLoaded) {
            if (state.payments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد دفعات مسجلة',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddPaymentScreen(
                              studentId: widget.studentId,
                              onPaymentAdded: () {
                                if (widget.studentId != null) {
                                  _paymentBloc.add(
                                    LoadStudentPaymentsEvent(widget.studentId!),
                                  );
                                } else {
                                  _paymentBloc.add(LoadPaymentsEvent());
                                }
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('تسجيل دفعة جديدة'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // إحصائيات سريعة (فقط في قائمة الكل)
                if (widget.studentId == null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.account_balance_wallet,
                          '${state.totalIncome.toStringAsFixed(0)} دج',
                          'إجمالي الدخل',
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildStatItem(
                          Icons.warning_amber,
                          '${state.totalOutstanding.toStringAsFixed(0)} دج',
                          'المتأخرات',
                        ),
                      ],
                    ),
                  ),

                // قائمة الدفعات
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.payments.length,
                    itemBuilder: (context, index) {
                      final payment = state.payments[index];
                      return _buildPaymentCard(payment);
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentScreen(
                studentId: widget.studentId,
                onPaymentAdded: () {
                  if (widget.studentId != null) {
                    _paymentBloc.add(
                      LoadStudentPaymentsEvent(widget.studentId!),
                    );
                  } else {
                    _paymentBloc.add(LoadPaymentsEvent());
                  }
                },
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
*/

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentId != null ? 'دفعات الطالب' : 'الدفعات المالية',
        ),
      ),
      body: BlocConsumer<PaymentBloc, PaymentState>(
        bloc: _paymentBloc,
        listener: (context, state) {
          if (state is PaymentOperationSuccess) {
            CustomSnackbar.showSuccess(context, state.message);
          }
          if (state is PaymentError) {
            CustomSnackbar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is PaymentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PaymentsLoaded) {
            if (state.payments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد دفعات مسجلة',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddPaymentScreen(
                              studentId:
                                  widget.studentId ?? 0, // ✅ تم الإصلاح هنا
                              onPaymentAdded: () {
                                if (widget.studentId != null) {
                                  _paymentBloc.add(
                                    LoadStudentPaymentsEvent(widget.studentId!),
                                  );
                                } else {
                                  _paymentBloc.add(LoadPaymentsEvent());
                                }
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('تسجيل دفعة جديدة'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // إحصائيات سريعة (فقط في قائمة الكل)
                if (widget.studentId == null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.account_balance_wallet,
                          '${state.totalIncome.toStringAsFixed(0)} دج',
                          'إجمالي الدخل',
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildStatItem(
                          Icons.warning_amber,
                          '${state.totalOutstanding.toStringAsFixed(0)} دج',
                          'المتأخرات',
                        ),
                      ],
                    ),
                  ),

                // قائمة الدفعات
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.payments.length,
                    itemBuilder: (context, index) {
                      final payment = state.payments[index];
                      return _buildPaymentCard(payment);
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentScreen(
                studentId: widget.studentId ?? 0, // ✅ تم الإصلاح هنا أيضاً
                onPaymentAdded: () {
                  if (widget.studentId != null) {
                    _paymentBloc.add(
                      LoadStudentPaymentsEvent(widget.studentId!),
                    );
                  } else {
                    _paymentBloc.add(LoadPaymentsEvent());
                  }
                },
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPaymentColor(
            payment.paymentType,
          ).withOpacity(0.1),
          child: Icon(
            _getPaymentIcon(payment.paymentType),
            color: _getPaymentColor(payment.paymentType),
          ),
        ),
        title: Text(
          payment.paymentTypeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${_formatDate(payment.paymentDate)}'),
            if (payment.isGifted)
              const Text(
                '🚀 إهداء',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            if (payment.extraReason != null)
              Text(
                'السبب: ${payment.extraReason}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${payment.amount.toStringAsFixed(0)} دج',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: payment.isGifted
                    ? Colors.green
                    : const Color(0xFFE53935),
              ),
            ),
            if (payment.paymentType == 'monthly' && payment.month != null)
              Text(
                'شهر ${payment.month}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        onTap: () {
          _showPaymentDetails(payment);
        },
      ),
    );
  }

  Color _getPaymentColor(String type) {
    switch (type) {
      case 'monthly':
        return Colors.blue;
      case 'insurance':
        return Colors.green;
      case 'extra':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'monthly':
        return Icons.calendar_today;
      case 'insurance':
        return Icons.security;
      case 'extra':
        return Icons.shopping_bag;
      default:
        return Icons.payment;
    }
  }

  void _showPaymentDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الدفعة - ${payment.paymentTypeName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'المبلغ',
              '${payment.amount.toStringAsFixed(0)} دج',
            ),
            _buildDetailRow('التاريخ', _formatDate(payment.paymentDate)),
            if (payment.month != null)
              _buildDetailRow('الشهر', '${payment.month}'),
            if (payment.year != null)
              _buildDetailRow('السنة', '${payment.year}'),
            if (payment.extraReason != null)
              _buildDetailRow('السبب', payment.extraReason!),
            if (payment.isGifted) _buildDetailRow('نوع الدفعة', 'إهداء 🚀'),
            if (payment.notes != null)
              _buildDetailRow('ملاحظات', payment.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(payment.id!);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(int paymentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الدفعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _paymentBloc.add(DeletePaymentEvent(paymentId));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
