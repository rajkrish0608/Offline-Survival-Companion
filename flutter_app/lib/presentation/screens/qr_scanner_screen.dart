import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/qr/qr_code_service.dart';
import 'package:uuid/uuid.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final QrCodeService _qrCodeService = QrCodeService();
  bool _isScanned = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on, color: Colors.yellow),
            iconSize: 32.0,
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flip_camera_android),
            iconSize: 32.0,
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? rawValue = barcodes.first.rawValue;
                if (rawValue != null) {
                  setState(() {
                    _isScanned = true;
                  });
                  _handleQrCode(rawValue);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentBlue, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (_isScanned)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Align QR code within the box',
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black45,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQrCode(String data) async {
    // Determine type (very basic)
    String type = 'text';
    if (data.startsWith('http')) {
      type = 'url';
    } else if (data.startsWith('WIFI:')) {
      type = 'wifi';
    } else if (data.startsWith('BEGIN:VCARD')) {
      type = 'contact';
    }

    final newItem = QrCodeItem(
      id: const Uuid().v4(),
      data: data,
      label: 'Scanned at ${DateTime.now().hour}:${DateTime.now().minute}',
      type: type,
      timestamp: DateTime.now(),
    );

    await _qrCodeService.saveCode(newItem);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('QR Code Scanned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${type.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(data, maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to Home
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
