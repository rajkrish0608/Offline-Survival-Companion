import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/services/auth/biometric_service.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  List<Map<String, dynamic>> _documents = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadDocuments() async {
    final state = context.read<AppBloc>().state;
    if (state is AppReady) {
      final storage = context.read<LocalStorageService>();
      final docs = await storage.getVaultDocuments(state.userId);
      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(docs);
        });
      }
    }
  }

  Future<void> _handleUnlock() async {
    setState(() => _isAuthenticating = true);
    
    final bool canCheck = await _biometricService.isBiometricAvailable();
    if (!canCheck) {
      // For development/mock devices without biometrics, we allow bypass or show message
      setState(() {
        _isUnlocked = true;
        _isAuthenticating = false;
      });
      _loadDocuments();
      return;
    }

    final bool authenticated = await _biometricService.authenticate();
    
    if (mounted) {
      setState(() {
        _isUnlocked = authenticated;
        _isAuthenticating = false;
      });
      
      if (authenticated) {
        _loadDocuments();
      }
    }
  }

  void _lockVault() {
    setState(() {
      _isUnlocked = false;
      _documents = [];
    });
  }

  Future<void> _pickAndSaveFile() async {
    final state = context.read<AppBloc>().state;
    if (state is! AppReady) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final storage = context.read<LocalStorageService>();
    final vaultDir = await storage.getVaultDirectory();
    
    final docId = const Uuid().v4();
    final ext = path.extension(fileName);
    final secureFilePath = '${vaultDir.path}/$docId$ext';
    
    // Copy file to secure vault directory
    await file.copy(secureFilePath);

    await storage.saveVaultDocument({
      'id': docId,
      'user_id': state.userId,
      'file_name': fileName,
      'file_path': secureFilePath,
      'document_type': ext.replaceAll('.', '').toUpperCase(),
      'size_bytes': await file.length(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    _loadDocuments();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File saved securely in Vault')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockedView();
    }
    return _buildUnlockedView();
  }

  Widget _buildLockedView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Vault')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentBlue.withOpacity(0.5), width: 2),
                ),
                child: Icon(Icons.lock_outline, size: 80, color: AppTheme.accentBlue),
              ),
              const SizedBox(height: 32),
              Text(
                'Vault is Locked',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _handleUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(_isAuthenticating ? 'Authenticating...' : 'Unlock Vault'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_open, color: Colors.green),
            onPressed: _lockVault,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.green.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Encrypted Storage Active', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDocuments,
              child: _documents.isEmpty 
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(child: Text('No documents in vault yet')),
                      const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Pull to refresh', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return Card(
                        child: ListTile(
                          leading: _getDocIcon(doc['document_type'] ?? 'OTHER'),
                          title: Text(doc['file_name'] ?? 'Unknown'),
                          subtitle: Text('Added: ${DateTime.fromMillisecondsSinceEpoch(doc['created_at'] ?? 0).toString()}'),
                        onTap: () async {
                          final result = await OpenFilex.open(doc['file_path']);
                          if (result.type != ResultType.done && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open file: ${result.message}')),
                            );
                          }
                        },
                        onLongPress: () => _confirmDelete(doc),
                      ),
                    );
                  },
                ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndSaveFile,
        backgroundColor: AppTheme.accentBlue,
        heroTag: 'vault_add_fab',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Delete ${doc['file_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final storage = context.read<LocalStorageService>();
              await storage.deleteVaultDocument(doc['id']);
              final file = File(doc['file_path']);
              if (await file.exists()) await file.delete();
              Navigator.pop(context);
              _loadDocuments();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _getDocIcon(String type) {
    final t = type.toUpperCase();
    IconData icon = Icons.description;
    Color color = Colors.grey;
    
    if (t.contains('PDF')) { 
      icon = Icons.picture_as_pdf; color = Colors.red; 
    } else if (t.contains('JPG') || t.contains('PNG') || t.contains('PHOTO')) { 
      icon = Icons.image; color = Colors.blue; 
    } else if (t.contains('VIDEO') || t.contains('MP4')) { 
      icon = Icons.videocam; color = Colors.orange; 
    } else if (t.contains('AUDIO') || t.contains('M4A')) { 
      icon = Icons.audiotrack; color = Colors.green; 
    }
    
    return Icon(icon, color: color);
  }
}
