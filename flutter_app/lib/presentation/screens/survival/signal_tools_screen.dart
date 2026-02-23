import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:torch_light/torch_light.dart';

class SignalToolsScreen extends StatefulWidget {
  const SignalToolsScreen({super.key});

  @override
  State<SignalToolsScreen> createState() => _SignalToolsScreenState();
}

class _SignalToolsScreenState extends State<SignalToolsScreen> {
  bool _isMorseActive = false;
  bool _isFlareActive = false;
  Timer? _morseTimer;
  Timer? _flareTimer;
  Color _flareColor = Colors.white;

  // Morse SOS: ... --- ...
  final List<int> _sosPattern = [
    200, 200, 200, 200, 200, 600, // S: . . .
    600, 200, 600, 200, 600, 600, // O: - - -
    200, 200, 200, 200, 200, 1400, // S: . . .
  ];

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  void _stopAll() {
    _morseTimer?.cancel();
    _flareTimer?.cancel();
    _isMorseActive = false;
    _isFlareActive = false;
    context.read<EmergencyService>().disableFlashlight();
  }

  Future<void> _toggleMorse() async {
    if (_isMorseActive) {
      _stopAll();
      setState(() {});
      return;
    }

    _stopAll();
    setState(() => _isMorseActive = true);

    int index = 0;
    void runCycle() async {
      if (!_isMorseActive) return;

      bool isOn = index % 2 == 0;
      int duration = _sosPattern[index];

      if (isOn) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }

      _morseTimer = Timer(Duration(milliseconds: duration), () {
        index = (index + 1) % _sosPattern.length;
        runCycle();
      });
    }

    runCycle();
  }

  void _toggleFlare() {
    if (_isFlareActive) {
      _stopAll();
      setState(() {});
      return;
    }

    _stopAll();
    setState(() => _isFlareActive = true);

    _flareTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _flareColor = _flareColor == Colors.white ? Colors.red : Colors.white;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFlareActive ? _flareColor : null,
      appBar: _isFlareActive 
          ? null 
          : AppBar(
              title: const Text('Signal Tools'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isFlareActive) ...[
                  const Icon(Icons.settings_input_antenna, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'Emergency Signaling',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use these tools to signal for help if you are lost or in danger.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                ],
                
                Row(
                  children: [
                    Expanded(
                      child: _SignalCard(
                        title: 'Morse SOS',
                        subtitle: 'Flashlight SOS',
                        icon: Icons.flashlight_on,
                        isActive: _isMorseActive,
                        onTap: _toggleMorse,
                        activeColor: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SignalCard(
                        title: 'Signal Flare',
                        subtitle: 'Screen Flash',
                        icon: Icons.wb_sunny,
                        isActive: _isFlareActive,
                        onTap: _toggleFlare,
                        activeColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isFlareActive)
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 32),
                onPressed: _stopAll,
              ),
            ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _SignalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: activeColor.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isActive ? Colors.white : activeColor,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
