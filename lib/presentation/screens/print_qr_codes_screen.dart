// lib/presentation/screens/print_qr_codes_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../injection/dependency_injection.dart';
import '../../core/widgets/custom_snackbar.dart';

class PrintQRCodesScreen extends StatefulWidget {
  const PrintQRCodesScreen({super.key});

  @override
  State<PrintQRCodesScreen> createState() => _PrintQRCodesScreenState();
}

class _PrintQRCodesScreenState extends State<PrintQRCodesScreen> {
  late StudentRepository _studentRepo;
  List<StudentModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _studentRepo = StudentRepository(localDb: getIt(), remoteApi: getIt());
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _students = await _studentRepo.getAllStudents();
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في تحميل الطلاب');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('طباعة QR Codes (${_students.length} طالب)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _students.isEmpty ? null : _printQRCodes,
            tooltip: 'طباعة',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد طلاب',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(context),
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return _buildQRCard(student);
              },
            ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 500) return 2;
    if (width < 800) return 3;
    if (width < 1100) return 4;
    return 5;
  }

  Widget _buildQRCard(StudentModel student) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: student.id.toString(),
                version: QrVersions.auto,
                size: 100,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // اسم الطالب
            Text(
              student.fullName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '#${student.id}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printQRCodes() async {
    // TODO: طباعة QR Codes
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('جاري الطباعة...')));
  }
}
