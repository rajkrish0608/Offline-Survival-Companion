import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offline_survival_companion/services/qr/qr_code_service.dart';
import 'package:uuid/uuid.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final QrCodeService _qrService = QrCodeService();
  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  
  bool _isScanning = true;

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        // Stop scanning and show save dialog
        setState(() => _isScanning = false);
        _showSaveDialog(code);
      }
    }
  }

  void _showSaveDialog(String data) {
    _manualController.text = data;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Data: $data', maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (e.g., Home WiFi)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true); // Resume scanning
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_labelController.text.isEmpty) return;
              
              final item = QrCodeItem(
                id: const Uuid().v4(),
                data: data,
                label: _labelController.text,
                type: _determineType(data),
                timestamp: DateTime.now(),
              );
              
              await _qrService.saveCode(item);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to list/home or stay? Let's go back for now
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR Code saved successfully!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _determineType(String data) {
    if (data.startsWith('WIFI:')) return 'WiFi';
    if (data.startsWith('http')) return 'URL';
    if (data.startsWith('MECARD:') || data.startsWith('vCard')) return 'Contact';
    return 'Text';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: () {
               setState(() => _isScanning = false);
               _showSaveDialog(''); // Open dialog with empty data for manual entry
            },
            tooltip: 'Manual Entry',
          ),
        ],
      ),
      body: _isScanning 
        ? MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Camera Error: ${error.errorCode}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _isScanning = false);
                        _showSaveDialog('');
                      },
                      child: const Text('Use Manual Entry'),
                    ),
                  ],
                ),
              );
            },
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Camera paused or unavailable.\nUse manual entry to save a code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Enter Data Manually'),
                    onPressed: () => _showSaveDialog(''),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
