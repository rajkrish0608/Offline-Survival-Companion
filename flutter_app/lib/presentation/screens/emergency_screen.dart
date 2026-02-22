import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _sosActive = false;
  bool _flashlightActive = false;
  bool _alarmActive = false;
  final int _batteryLevel = 100;
  String _lastLocation = 'Fetching location...';
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _simulateSOSActivation();
  }

  void _simulateSOSActivation() {
    // Simulate SOS activation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _sosActive = true;
          _flashlightActive = true;
        });

        // Simulate location update
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _lastLocation = '12.9716° N, 77.5946° E';
            });
          }
        });

        // Simulate elapsed time
        Duration elapsed = Duration.zero;
        Future.doWhile(() async {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted && _sosActive) {
            elapsed = elapsed + const Duration(seconds: 1);
            setState(() {
              _elapsedTime = elapsed;
            });
            return true;
          }
          return false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Status Bar
            Container(
              color: AppTheme.surfaceDark,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS Accuracy: High',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successGreen,
                        ),
                      ),
                      Text(
                        'Battery: $_batteryLevel%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _batteryLevel < 20
                              ? AppTheme.primaryRed
                              : AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDuration(_elapsedTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _sosActive ? '⎕ SOS ACTIVE' : 'SOS Inactive',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _sosActive
                              ? AppTheme.primaryRed
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Location Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Location Info
                    Card(
                      color: AppTheme.surfaceDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _lastLocation,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                // Copy to clipboard or share
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Location copied'),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: AppTheme.accentBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Copy location',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.accentBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons (2x2 Grid)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _EmergencyActionButton(
                          icon: Icons.light,
                          label: 'Flashlight',
                          isActive: _flashlightActive,
                          onTap: () {
                            setState(() {
                              _flashlightActive = !_flashlightActive;
                            });
                          },
                        ),
                        _EmergencyActionButton(
                          icon: Icons.volume_up,
                          label: 'Loud Alarm',
                          isActive: _alarmActive,
                          onTap: () {
                            setState(() {
                              _alarmActive = !_alarmActive;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _alarmActive ? 'Loud Alarm ACTIVATED' : 'Alarm Silenced',
                                ),
                                backgroundColor: _alarmActive ? Colors.red : null,
                              ),
                            );
                          },
                        ),
                        _EmergencyActionButton(
                          icon: Icons.local_hospital,
                          label: 'Hospital',
                          isActive: false,
                          onTap: () {
                             context.push('/maps');
                          },
                        ),
                        _EmergencyActionButton(
                          icon: Icons.medical_services,
                          label: 'First Aid',
                          isActive: false,
                          onTap: () {
                            context.push('/guide');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Contact Status
                    Card(
                      color: AppTheme.surfaceDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Status',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            _ContactStatusItem(
                              name: 'Mom',
                              status: 'SMS Delivered',
                              icon: Icons.check_circle,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(height: 8),
                            _ContactStatusItem(
                              name: 'Dad',
                              status: 'SMS Delivered',
                              icon: Icons.check_circle,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(height: 8),
                            _ContactStatusItem(
                              name: 'Emergency',
                              status: 'SMS Failed (Retry)',
                              icon: Icons.warning,
                              color: AppTheme.warningYellow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Deactivate Button (Full Width at Bottom)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('End Emergency'),
                        content: const Text(
                          'Are you sure? This will stop location sharing.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'End',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      setState(() {
                        _sosActive = false;
                        _flashlightActive = false;
                        _alarmActive = false;
                      });
                      if (mounted) {
                        context.pop();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                  ),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('End Emergency Mode'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$minutes:$seconds';
  }
}

class _EmergencyActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _EmergencyActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isActive
            ? AppTheme.primaryRed.withValues(alpha: 0.2)
            : AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive ? AppTheme.primaryRed : AppTheme.borderDark,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isActive ? AppTheme.primaryRed : AppTheme.textLight,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? AppTheme.primaryRed : AppTheme.textLight,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactStatusItem extends StatelessWidget {
  final String name;
  final String status;
  final IconData icon;
  final Color color;

  const _ContactStatusItem({
    required this.name,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                status,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
