import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/screens/emergency_contacts_screen.dart';
import 'package:offline_survival_companion/presentation/widgets/low_battery_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Secret admin access: tap version 7 times
  int _versionTapCount = 0;
  static const int _requiredTaps = 7;
  DateTime? _lastTapTime;

  void _onVersionTap() {
    final now = DateTime.now();

    // Reset if more than 2 seconds passed between taps
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inSeconds > 2) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    final remaining = _requiredTaps - _versionTapCount;

    if (_versionTapCount >= _requiredTaps) {
      // Unlock — navigate to admin
      _versionTapCount = 0;
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pushNamed('/admin');
    } else if (remaining <= 3) {
      // Show countdown hint only in the last 3 taps
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$remaining more tap${remaining == 1 ? '' : 's'} to unlock developer options'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all saved webpages, QR codes, and reset settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final dir = await getApplicationDocumentsDirectory();
        if (await dir.exists()) {
          dir.deleteSync(recursive: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('All data cleared. Please restart the app.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Emergency'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.contact_phone, color: Colors.red),
              title: const Text('Emergency Contacts'),
              subtitle: const Text('People notified when SOS is activated'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmergencyContactsScreen(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Power Management'),
          const LowBatteryToggle(),

          const SizedBox(height: 24),
          _buildSectionHeader('Data & Privacy'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.sync, color: AppTheme.accentBlue),
                  title: const Text('Sync Now'),
                  subtitle:
                      const Text('Check for map & guide updates'),
                  onTap: () {
                    context
                        .read<AppBloc>()
                        .add(const SyncRequested());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync started...')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.red),
                  title: const Text('Clear All Data'),
                  subtitle: const Text(
                      'Delete saved pages, codes & settings'),
                  onTap: _clearAllData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('About'),
          Card(
            child: Column(
              children: [
                // 🔒 Secret admin trigger — tap version 7 times rapidly
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: const Text('1.0.0 (Beta)'),
                  onTap: _onVersionTap,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_center_outlined,
                      color: Colors.orange),
                  title: const Text('App User Manual'),
                  subtitle: const Text('How to use every feature'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/user-manual'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
          const Center(
            child: Text(
              'Offline Survival Companion\nBuilt for resilience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
