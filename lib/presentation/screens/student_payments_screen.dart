// lib/presentation/screens/student_payments_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../injection/dependency_injection.dart';
import 'add_payment_screen.dart';

class StudentPaymentsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentPaymentsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentPaymentsScreen> createState() => _StudentPaymentsScreenState();
}

class _StudentPaymentsScreenState extends State<StudentPaymentsScreen> {
  late PaymentRepository _paymentRepo;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  double _totalPaid = 0;

  @override
  void initState() {
    super.initState();
    _paymentRepo = PaymentRepository(localDb: getIt());
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payments = await _paymentRepo.getStudentPayments(widget.studentId);
      setState(() {
        _payments = payments;
        _totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          studentId: widget.studentId,
          onPaymentAdded: () {
            _loadPayments();
          },
        ),
      ),
    );
    if (result == true) {
      _loadPayments();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  String _getPaymentTypeName(String type) {
    switch (type) {
      case 'monthly':
        return 'اشتراك شهري';
      case 'insurance':
        return 'حقوق التأمين';
      case 'extra':
        return 'مستحقات إضافية';
      default:
        return type;
    }
  }

  void _showPaymentDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل الدفعة - ${_getPaymentTypeName(payment.paymentType)}',
        ),
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
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مدفوعات ${widget.studentName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد مدفوعات مسجلة',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addPayment,
                            icon: const Icon(Icons.add),
                            label: const Text('تسجيل دفعة جديدة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // بطاقة الإجمالي
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFC62828)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'إجمالي المدفوعات',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_totalPaid.toStringAsFixed(0)} دج',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'عدد الدفعات: ${_payments.length}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // قائمة الدفعات
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getPaymentColor(
                                      payment.paymentType,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      _getPaymentIcon(payment.paymentType),
                                      color: _getPaymentColor(
                                        payment.paymentType,
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    _getPaymentTypeName(payment.paymentType),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDate(payment.paymentDate),
                                  ),
                                  trailing: Text(
                                    '${payment.amount.toStringAsFixed(0)} دج',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: payment.isGifted
                                          ? Colors.green
                                          : const Color(0xFFE53935),
                                    ),
                                  ),
                                  onTap: () => _showPaymentDetails(payment),
                                ),
                              );
                            },
                          ),
                        ),

                        // زر الإضافة
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ElevatedButton.icon(
                            onPressed: _addPayment,
                            icon: const Icon(Icons.add),
                            label: const Text('تسجيل دفعة جديدة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
