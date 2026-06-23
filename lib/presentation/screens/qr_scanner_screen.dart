// lib/presentation/screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<QRScannerScreenState> qrScannerKey =
    GlobalKey<QRScannerScreenState>();

class ScanResult {
  final String studentId;
  final String? studentName;
  final String? studentLastName;
  final String status;

  ScanResult({
    required this.studentId,
    this.studentName,
    this.studentLastName,
    required this.status,
  });
}

class QRScannerScreen extends StatefulWidget {
  final String? title;
  final bool continuousMode;
  final Function(ScanResult)? onScan;
  final int? totalStudents;

  const QRScannerScreen({
    super.key,
    this.title,
    this.continuousMode = false,
    this.onScan,
    this.totalStudents,
  });

  @override
  State<QRScannerScreen> createState() => QRScannerScreenState();
}

class QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController _controller;

  bool _isScanning = true;
  bool _hasPermission = false;
  String? _errorMessage;
  List<String> _scannedIds = [];

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  // ⏳ زيادة وقت الكوول داون (المهلة) لمنع التكرار الفوري لنفس الكود إلى 2.5 ثانية
  static const Duration _scanCooldown = Duration(milliseconds: 2500);

  bool _isProcessing = false;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, // سرعة عادية ومستقرة
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
          _errorMessage = 'الرجاء منح صلاحية الكاميرا';
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

// ==================== معالجة المسح الذكية ====================
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isDialogOpen) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final String? rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // 🛡️ [حماية التكرار المباشر لفوق الكود]: التحقق من المهلة الزمنية لنفس الكود
    final now = DateTime.now();
    if (_lastScannedCode == rawValue &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanCooldown) {
      print('⏳ تم تجاهل المسح: الكاميرا لا تزال فوق نفس الكود السابق');
      return;
    }

    final corners = barcode.corners;
    if (corners == null || corners.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    final cameraSize = capture.size;
    if (cameraSize.width == 0 || cameraSize.height == 0) return;

    final double scaleX = screenSize.width / cameraSize.width;
    final double scaleY = screenSize.height / cameraSize.height;

    double left = corners[0].dx * scaleX;
    double top = corners[0].dy * scaleY;
    double right = corners[0].dx * scaleX;
    double bottom = corners[0].dy * scaleY;

    for (final corner in corners) {
      final scaledX = corner.dx * scaleX;
      final scaledY = corner.dy * scaleY;
      if (scaledX < left) left = scaledX;
      if (scaledX > right) right = scaledX;
      if (scaledY < top) top = scaledY;
      if (scaledY > bottom) bottom = scaledY;
    }

    final codeRect = Rect.fromLTRB(left, top, right, bottom);

    final frameSize = 250.0;
    final frameLeft = (screenSize.width - frameSize) / 2;
    final frameTop = (screenSize.height - frameSize) / 2;
    final frameRight = frameLeft + frameSize;
    final frameBottom = frameTop + frameSize;

    final isInsideFrame = codeRect.left >= (frameLeft - 40) &&
        codeRect.right <= (frameRight + 40) &&
        codeRect.top >= (frameTop - 40) &&
        codeRect.bottom <= (frameBottom + 40);

    if (!isInsideFrame) {
      return;
    }

    // حفظ بيانات الكود الحالي ووقت مسحه
    _lastScannedCode = rawValue;
    _lastScanTime = now;

    setState(() {
      _isProcessing = true;
      _isDialogOpen = true;
      if (!_scannedIds.contains(rawValue)) {
        _scannedIds.add(rawValue);
      }
    });

    if (widget.onScan != null) {
      final tempResult = ScanResult(
        studentId: rawValue,
        studentName: 'جاري التحقق...',
        studentLastName: '',
        status: 'checking',
      );
      widget.onScan!(tempResult);
    } else {
      _showTestDialog(rawValue);
    }
  }

  // ==================== إعادة تفعيل المسح من الخارج ====================
  void resumeScanningFromOutside() {
    print('🔄 [outside] إعادة تفعيل المسح');
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isDialogOpen = false;
        // 💡 ملاحظة: لم نقم بمسح _lastScannedCode هنا عمداً لتستمر حماية منع التكرار الفوري لنفس الكود
      });
    }
  }

  // ==================== إعادة تفعيل المسح الداخلي ====================
  void resumeScanning() {
    print('🔄 إعادة تفعيل المسح الداخلي');
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isDialogOpen = false;
      });
    }
  }

  // ==================== عرض نافذة تجريبية ====================
  void _showTestDialog(String studentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة المسح'),
        content: Text('تم مسح الكود: $studentId'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resumeScanning();
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  // ==================== عرض نافذة النتيجة المحدثة ====================
  void showResultDialog({
    required String studentId,
    required String studentName,
    required String studentLastName,
    required String status,
    VoidCallback? onConfirm,
  }) {
    Color backgroundColor;
    String icon;
    String message;
    String buttonText;

    switch (status) {
      case 'new':
        backgroundColor = Colors.green.shade700;
        icon = '✅';
        message = 'تسجيل الحضور';
        buttonText = 'حاضر';
        break;
      case 'duplicate':
        backgroundColor = Colors.orange.shade700;
        icon = '⚠️';
        message = 'تم تسجيل الحضور مسبقاً';
        buttonText = 'تم التسجيل';
        break;
      case 'not_found':
        backgroundColor = Colors.red.shade700;
        icon = '❌';
        message = 'غير موجود في هذا الفوج';
        buttonText = 'لا ينتمي';
        break;
      default:
        backgroundColor = Colors.grey.shade700;
        icon = 'ℹ️';
        message = 'غير معروف';
        buttonText = 'تم';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                icon,
                style: const TextStyle(fontSize: 40),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$studentName $studentLastName'.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onConfirm != null) {
                    onConfirm();
                  }
                  // تفعيل المسح فور إغلاق نافذة النتيجة المخصصة
                  resumeScanning();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finishScanning() {
    Navigator.pop(context, _scannedIds);
  }

  void _resetScanning() {
    setState(() {
      _scannedIds.clear();
      _lastScannedCode = null;
      _lastScanTime = null;
      _isProcessing = false;
    });
  }

  void _flashToggle() {
    _controller.toggleTorch();
  }

  void _cameraToggle() {
    _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final scanned = _scannedIds.length;
    final total = widget.totalStudents ?? 0;
    final progress = total > 0 ? scanned / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.continuousMode
              ? 'مسح QR - $scanned / ${widget.totalStudents ?? "?"}'
              : (widget.title ?? 'مسح QR Code'),
        ),
        actions: [
          if (widget.continuousMode) ...[
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _resetScanning,
              tooltip: 'إعادة تعيين',
            ),
            TextButton(
              onPressed: scanned > 0 ? _finishScanning : null,
              child: Text(
                'تم ($scanned)',
                style: TextStyle(
                  color: scanned > 0 ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
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
        bottom: widget.continuousMode && total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.greenAccent,
                  ),
                  minHeight: 4,
                ),
              )
            : null,
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
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          fit: BoxFit.cover,
        ),
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
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
              ],
            ),
          ),
        ),
        if (widget.continuousMode)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '📷 ${_scannedIds.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
              child: const Text(
                'ضع كود QR داخل الإطار',
                style: TextStyle(color: Colors.white, fontSize: 14),
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
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: alignment.y == 1
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: alignment.x == -1
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: alignment.x == 1
                ? const BorderSide(color: Colors.white, width: 4)
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
