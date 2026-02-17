import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_survival_companion/services/qr/qr_code_service.dart';
import 'package:offline_survival_companion/presentation/screens/qr_scanner_screen.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class SavedQrCodesScreen extends StatefulWidget {
  const SavedQrCodesScreen({Key? key}) : super(key: key);

  @override
  State<SavedQrCodesScreen> createState() => _SavedQrCodesScreenState();
}

class _SavedQrCodesScreenState extends State<SavedQrCodesScreen> {
  final QrCodeService _qrService = QrCodeService();
  List<QrCodeItem> _savedCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);
    final codes = await _qrService.getSavedCodes();
    if (mounted) {
      setState(() {
        _savedCodes = codes.reversed.toList(); // Newest first
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCode(String id) async {
    await _qrService.deleteCode(id);
    _loadCodes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code deleted')),
      );
    }
  }

  void _copyToClipboard(String data) {
    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved QR Codes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
          _loadCodes(); // Refresh list on return
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan New'),
        backgroundColor: AppTheme.accentBlue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedCodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No saved codes yet'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                          );
                          _loadCodes();
                        },
                        child: const Text('Scan or Add Manually'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                  itemCount: _savedCodes.length,
                  itemBuilder: (context, index) {
                    final item = _savedCodes[index];
                    return Dismissible(
                      key: Key(item.id),
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteCode(item.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                            child: Icon(_getIconForType(item.type), color: AppTheme.accentBlue),
                          ),
                          title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.data, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () => _copyToClipboard(item.data),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(item.label),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Type: ${item.type}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      SelectableText(item.data),
                                      const SizedBox(height: 16),
                                      Text('Saved: ${item.timestamp.toString().split('.')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'WiFi': return Icons.wifi;
      case 'URL': return Icons.link;
      case 'Contact': return Icons.person;
      default: return Icons.text_fields;
    }
  }
}
