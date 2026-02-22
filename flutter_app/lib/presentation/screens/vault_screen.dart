import 'package:flutter/material.dart';
import 'package:offline_survival_companion/services/auth/biometric_service.dart';
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

  final List<Map<String, String>> _documents = [
    {'title': 'Passport Copy', 'type': 'PDF', 'date': '2024-01-15'},
    {'title': 'Emergency Insurance', 'type': 'DOCX', 'date': '2023-11-20'},
    {'title': 'Medical Records', 'type': 'PDF', 'date': '2024-02-01'},
    {'title': 'National ID Card', 'type': 'JPG', 'date': '2024-01-10'},
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleUnlock() async {
    setState(() => _isAuthenticating = true);
    
    final bool canCheck = await _biometricService.isBiometricAvailable();
    if (!canCheck) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometrics not available on this device')),
        );
      }
      setState(() => _isAuthenticating = false);
      return;
    }

    final bool authenticated = await _biometricService.authenticate();
    
    if (mounted) {
      setState(() {
        _isUnlocked = authenticated;
        _isAuthenticating = false;
      });
      
      if (authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault Unlocked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _lockVault() {
    setState(() {
      _isUnlocked = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault Locked')),
    );
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
              const SizedBox(height: 16),
              Text(
                'Access your encrypted sensitive documents securely.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _handleUnlock,
                  icon: _isAuthenticating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fingerprint),
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
            tooltip: 'Lock Vault',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text(
                  'End-to-End Encrypted Storage Active',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final doc = _documents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: _getDocIcon(doc['type']!),
                    title: Text(doc['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Added: ${doc['date']} • ${doc['type']}'),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening ${doc['title']}...')),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File picker would open here (Simulation)')),
          );
        },
        backgroundColor: AppTheme.accentBlue,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _getDocIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'PDF':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'JPG':
        icon = Icons.image;
        color = Colors.blue;
        break;
      default:
        icon = Icons.description;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}
