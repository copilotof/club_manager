// lib/presentation/screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QRScannerScreen extends StatefulWidget {
  final String? title;
  final bool continuousMode;

  const QRScannerScreen({super.key, this.title, this.continuousMode = false});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController _controller;
  bool _isScanning = true;
  bool _hasPermission = false;
  String? _errorMessage;
  List<String> _scannedCodes = [];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: [BarcodeFormat.qrCode],
    );
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'الرجاء منح صلاحية الكاميرا لاستخدام QR Code';
        });
      }
    } else if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _hasPermission = false;
        _errorMessage = 'صلاحية الكاميرا غير متاحة';
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final String? rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // اهتزاز للتنبيه
    HapticFeedback.mediumImpact();

    if (widget.continuousMode) {
      // ✅ وضع المسح المتسلسل
      setState(() {
        _scannedCodes.add(rawValue);
      });

      // إظهار رسالة سريعة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم مسح: ${_scannedCodes.length} طالب'),
          duration: const Duration(milliseconds: 300),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ إعادة تفعيل المسح للمرة التالية
      _isScanning = true;
    } else {
      // ✅ وضع المسح العادي
      setState(() {
        _isScanning = false;
      });
      Navigator.pop(context, rawValue);
    }
  }

  void _finishScanning() {
    Navigator.pop(context, _scannedCodes);
  }

  void _flashToggle() {
    _controller.toggleTorch();
  }

  void _cameraToggle() {
    _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.continuousMode
              ? 'مسح QR - ${_scannedCodes.length} طالب'
              : (widget.title ?? 'مسح QR Code'),
        ),
        actions: [
          if (widget.continuousMode)
            TextButton(
              onPressed: _scannedCodes.isEmpty ? null : _finishScanning,
              child: Text(
                'تم (${_scannedCodes.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _flashToggle,
            tooltip: 'تشغيل/إيقاف الفلاش',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _cameraToggle,
            tooltip: 'تبديل الكاميرا',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermission,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('الرجاء منح صلاحية الكاميرا'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermission,
              child: const Text('طلب الصلاحية'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // كاميرا المسح
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          fit: BoxFit.cover,
        ),

        // إطار المسح
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // الزوايا الأربع للإطار
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
              ],
            ),
          ),
        ),

        // رسالة في الأسفل
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.continuousMode
                    ? 'امسح رموز الطلاب الحاضرين'
                    : 'ضع كود QR داخل الإطار',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y == -1
                ? BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: alignment.y == 1
                ? BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: alignment.x == -1
                ? BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: alignment.x == 1
                ? BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
