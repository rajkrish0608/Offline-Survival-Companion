import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
      // Unlock — show dialog then navigate to admin
      _versionTapCount = 0;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showAdminUnlockDialog();
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

  void _showAdminUnlockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdminUnlockDialog(
        onProceed: () {
          Navigator.of(ctx).pop();
          context.push('/admin');
        },
      ),
    );
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
              onTap: () => context.push('/emergency-contacts'),
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
                  onTap: () => context.push('/user-manual'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of your account'),
                  onTap: () {
                    context.read<AppBloc>().add(const AppLoggedOut());
                    context.go('/login');
                  },
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

// ──────────────────────────────────────────────────────────────────────────────
// Secret Admin Unlock Dialog
// ──────────────────────────────────────────────────────────────────────────────

class _AdminUnlockDialog extends StatefulWidget {
  final VoidCallback onProceed;
  const _AdminUnlockDialog({required this.onProceed});

  @override
  State<_AdminUnlockDialog> createState() => _AdminUnlockDialogState();
}

class _AdminUnlockDialogState extends State<_AdminUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing shield icon with glow
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D1B2A),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      size: 52, color: Color(0xFF00E5FF)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Title
            const Text(
              'Admin Mode Unlocked',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Authorised access only.\nAll activity is logged.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Enter button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: widget.onProceed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Enter Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00E5FF),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.4))),
            ),
          ],
        ),
      ),
    );
  }
}
