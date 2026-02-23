import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/screens/maps_screen.dart';
import 'package:offline_survival_companion/presentation/screens/guide_screen.dart';
import 'package:offline_survival_companion/presentation/screens/vault_screen.dart';
import 'package:offline_survival_companion/presentation/screens/webpage_saver_screen.dart';
import 'package:offline_survival_companion/presentation/screens/emergency_contacts_screen.dart';
import 'package:offline_survival_companion/presentation/screens/settings_screen.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:offline_survival_companion/services/audio/alarm_service.dart';
import 'package:offline_survival_companion/presentation/widgets/safety/silent_sos_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Survival Companion'),
        elevation: 0,
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.download_for_offline),
              onPressed: () {
                // We'll use a GlobalKey or a simpler approach if needed, 
                // but for now let's just use the router to go to a dedicated downloads page if preferred, 
                // OR we'll just keep the existing Stack-based approach in MapsScreen if we can trigger it.
                // Actually, let's keep it simple: Add a small download button directly on the map in MapsScreen.
              },
            ),
        ],
      ),
      body: _buildScreen(_selectedIndex),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/emergency'),
        backgroundColor: Colors.red,
        heroTag: 'home_sos_fab',
        label: const Text('SOS'),
        icon: const Icon(Icons.emergency),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Maps'),
          NavigationDestination(icon: Icon(Icons.lock), label: 'Vault'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Guide'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 1:
        return const MapsScreen();
      case 2:
        return const VaultScreen();
      case 3:
        return const GuideScreen();
      case 4:
        return const SettingsScreenContent();
      default:
        return const HomeScreenContent();
    }
  }
}

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'App is fully functional offline',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: SilentSOSButton(size: 140),
            ),
            const SizedBox(height: 24),

            // Women Safety Banner
            InkWell(
              onTap: () => context.push('/women-safety'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[700]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emergency_share, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Women Safety & Empowerment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fake Call, Safety Timer, and more',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  icon: Icons.light,
                  label: 'Flashlight',
                  onTap: () => context.read<AppBloc>().state is AppReady 
                    ? context.read<EmergencyService>().toggleFlashlight()
                    : null,
                ),
                _ActionCard(
                  icon: Icons.volume_up,
                  label: 'Alarm',
                  onTap: () => context.read<AlarmService>().toggle(),
                ),
                _ActionCard(
                  icon: Icons.contact_emergency,
                  label: 'Contacts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.sync,
                  label: 'Manual Sync',
                  onTap: () =>
                      context.read<AppBloc>().add(const SyncRequested()),
                ),
                _ActionCard(
                  icon: Icons.save_alt,
                  label: 'Web Saver',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WebpageSaverScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.qr_code,
                  label: 'QR Scanner',
                  onTap: () => context.push('/qr-scanner'),
                ),
                _ActionCard(
                  icon: Icons.settings_input_antenna,
                  label: 'Signal Tools',
                  onTap: () => context.push('/signal-tools'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class MapsScreenContent extends StatelessWidget {
  const MapsScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Maps Screen'),
          const SizedBox(height: 8),
          const Text('Download offline maps here'),
        ],
      ),
    );
  }
}


class GuideScreenContent extends StatelessWidget {
  const GuideScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Guide Screen'),
          const SizedBox(height: 8),
          const Text('First aid and survival guides'),
        ],
      ),
    );
  }
}

class SettingsScreenContent extends StatelessWidget {
  const SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: const SettingsScreen(),
    );
  }
}
