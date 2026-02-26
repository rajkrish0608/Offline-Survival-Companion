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
import 'package:offline_survival_companion/services/network/peer_mesh_service.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _startPassiveMeshListening();
  }

  Future<void> _startPassiveMeshListening() async {
    // We try to start discovery silently. It requires permissions,
    // so we must explicitly check and safely request them before starting
    // to prevent Android 14 Foreground Service SecurityExceptions.
    try {
      if (mounted) {
        // Must explicitly check permissions before starting FGS to prevent Android 14 crash
        final locStatus = await Permission.location.status;
        final blStatus = await Permission.bluetooth.status;
        final blConnectStatus = await Permission.bluetoothConnect.status;
        final blScanStatus = await Permission.bluetoothScan.status;

        // Check if all necessary permissions are granted
        if (locStatus.isGranted && 
            (blStatus.isGranted || blConnectStatus.isGranted || blScanStatus.isGranted)) {
          final peerMeshService = context.read<PeerMeshService>();
          await peerMeshService.startDiscovering();
          debugPrint('Passive mesh listening started successfully.');
        } else {
          debugPrint('Passive mesh listening skipped: permissions not yet granted.');
        }
      }
    } catch (e) {
      debugPrint('Could not start passive mesh listening: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarmService = context.read<AlarmService>();
    return StatefulBuilder(
      builder: (context, setStateBanner) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('Offline Survival Companion'),
                elevation: 0,
                actions: [
                  if (_selectedIndex == 1)
                    IconButton(
                      icon: const Icon(Icons.download_for_offline),
                      onPressed: () {},
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
            ),
            // Persistent STOP ALARM banner — shows on every tab when alarm is ringing
            if (alarmService.isPlaying)
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () async {
                      await alarmService.stop();
                      setStateBanner(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange[700],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.volume_off, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            '🔇 TAP TO STOP ALARM',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _staggeredAnimations = List.generate(
      4, // Number of main sections to stagger
      (index) => CurvedAnimation(
        parent: _controller,
        curve: Interval(
          0.1 * index,
          0.1 * index + 0.6,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _staggeredAnimations[0],
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_staggeredAnimations[0]),
                child: Card(
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
              ),
            ),
            // Mesh Network Status Indicator
            FadeTransition(
              opacity: _staggeredAnimations[1],
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'P2P Mesh Active',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _staggeredAnimations[1],
              child: const Center(
                child: SilentSOSButton(size: 140),
              ),
            ),
            const SizedBox(height: 24),

            // Women Safety Banner
            FadeTransition(
              opacity: _staggeredAnimations[2],
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(_staggeredAnimations[2]),
                child: InkWell(
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
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            FadeTransition(
              opacity: _staggeredAnimations[3],
              child: Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),

            FadeTransition(
              opacity: _staggeredAnimations[3],
              child: GridView.count(
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
                    onTap: () => context.push('/emergency-contacts'),
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
                    onTap: () => context.push('/web-saver'),
                  ),
                  _ActionCard(
                    icon: Icons.qr_code,
                    label: 'QR Scanner',
                    onTap: () => context.push('/qr-scanner'), // Fallback if no specific route
                  ),
                  _ActionCard(
                    icon: Icons.settings_input_antenna,
                    label: 'Signal Tools',
                    onTap: () => context.push('/signal-tools'),
                  ),
                  _ActionCard(
                    icon: Icons.help_outline,
                    label: 'User Manual',
                    onTap: () => context.push('/user-manual'),
                  ),
                ],
              ),
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
