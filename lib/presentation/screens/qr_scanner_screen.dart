import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/utils/responsive_utils.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح QR Code')),
      body: SingleChildScrollView(
        // ✅ مهم جداً!
        padding: EdgeInsets.all(
          ResponsiveUtils.responsiveSpacing(context, spacing: 16),
        ),
        child: Column(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    // نعيد النتيجة إلى الشاشة السابقة
                    Navigator.pop(context, barcode.rawValue);
                    return;
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
