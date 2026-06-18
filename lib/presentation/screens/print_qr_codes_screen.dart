// lib/presentation/screens/print_qr_codes_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
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
  bool _isGenerating = false;

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

  // ==================== توليد QR Code كصورة (تم الإصلاح هنا) ====================
  Future<ui.Image> _generateQRImage(String data, {double size = 200.0}) async {
    // نستخدم QrPainter المخصص لرسم البايتات وتوليد الصورة في الخلفية
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      gapless: true,
    );

    // تحويل الرسام إلى كائن صورة ui.Image بالاعتماد على الأبعاد المطلوبة
    final image = await qrPainter.toImage(size);
    return image;
  }

  // ==================== إنشاء PDF ====================
  Future<void> _generatePDF() async {
    if (_students.isEmpty) {
      CustomSnackbar.showError(context, 'لا يوجد طلاب لطباعة رموزهم');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final pdf = pw.Document();

      final pageFormat = PdfPageFormat.a4.copyWith(
        marginLeft: PdfPageFormat.cm * 0.5,
        marginRight: PdfPageFormat.cm * 0.5,
        marginTop: PdfPageFormat.cm * 0.5,
        marginBottom: PdfPageFormat.cm * 0.5,
      );

      const int cols = 3;
      const int rowsPerPage = 6;
      const int itemsPerPage = cols * rowsPerPage;

      // تقسيم الطلاب إلى صفحات
      for (
        int pageIndex = 0;
        pageIndex < _students.length;
        pageIndex += itemsPerPage
      ) {
        final pageStudents = _students
            .skip(pageIndex)
            .take(itemsPerPage)
            .toList();

        // 1. تجهيز مصفوفة لحفظ البيانات الثنائية للصور الجاهزة قبل البدء بالـ build
        List<Map<String, dynamic>> preparedStudentsData = [];

        for (var student in pageStudents) {
          final image = await _generateQRImage(student.id.toString());
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final pngBytes = bytes?.buffer.asUint8List();

          preparedStudentsData.add({
            'fullName': student.fullName,
            'id': student.id,
            'pngBytes': pngBytes,
          });
        }

        // 2. إضافة الصفحة بدالة تزامنية خفيفة
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              List<pw.Widget> qrWidgets = [];

              for (var data in preparedStudentsData) {
                final Uint8List? pngBytes = data['pngBytes'];

                qrWidgets.add(
                  pw.Container(
                    width: 120,
                    height: 140,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        if (pngBytes != null)
                          pw.Image(
                            pw.MemoryImage(
                              pngBytes,
                            ), // استخدام الـ MemoryImage هنا صحيح تماماً للـ PDF
                            width: 80,
                            height: 80,
                          ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          data['fullName'],
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '#${data['id']}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'رموز QR للطلاب',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Wrap(spacing: 20, runSpacing: 20, children: qrWidgets),
                ],
              );
            },
          ),
        );
      }

      // حفظ الملف
      final output = await getTemporaryDirectory();
      final filePath =
          '${output.path}/QR_Codes_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // مشاركة الملف
      await Share.shareXFiles([XFile(filePath)], text: 'ملف رموز QR للطلاب');

      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'تم إنشاء ملف PDF بنجاح');
    } catch (e) {
      print('❌ خطأ في إنشاء PDF: $e');
      if (!mounted) return;
      CustomSnackbar.showError(context, 'فشل إنشاء ملف PDF');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'طباعة QR Codes (${_students.length} طالب)',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: _isGenerating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isGenerating ? null : _generatePDF,
            tooltip: 'تصدير PDF',
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
                return _buildQRCardUI(student);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _generatePDF,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(_isGenerating ? 'جاري الإنشاء...' : 'تصدير PDF'),
        backgroundColor: const Color(0xFFE53935),
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

  // ==================== بطاقة QR في الواجهة ====================
  Widget _buildQRCardUI(StudentModel student) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
}
