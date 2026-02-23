import 'dart:async';
import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Dad');
  int _delaySeconds = 10;
  bool _isCountdownActive = false;
  bool _isRinging = false;
  bool _isCallActive = false;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isCountdownActive = true;
      _remainingSeconds = _delaySeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _startRinging();
      }
    });
  }

  void _startRinging() {
    setState(() {
      _isCountdownActive = false;
      _isRinging = true;
    });
  }

  void _answerCall() {
    setState(() {
      _isRinging = false;
      _isCallActive = true;
    });
  }

  void _endCall() {
    _timer?.cancel();
    setState(() {
      _isRinging = false;
      _isCallActive = false;
      _isCountdownActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRinging) return _buildRingingUI();
    if (_isCallActive) return _buildActiveCallUI();
    if (_isCountdownActive) return _buildCountdownUI();
    
    return _buildConfigUI();
  }

  Widget _buildConfigUI() {
    return Scaffold(
      appBar: AppBar(title: const Text('Fake Call Simulator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up a fake call to help you exit uncomfortable situations safely.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Caller Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Delay before call:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [10, 30, 60, 300].map((seconds) {
                final label = seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';
                return ChoiceChip(
                  label: Text(label),
                  selected: _delaySeconds == seconds,
                  onSelected: (selected) {
                    if (selected) setState(() => _delaySeconds = seconds);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startCountdown,
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule Fake Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Tip: Lock your phone and wait for the call.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, size: 80, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              'Call Scheduled',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Ringing in $_remainingSeconds seconds',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 64),
            TextButton(
              onPressed: _endCall,
              child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingingUI() {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.8), Colors.blue.withOpacity(0.2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              _nameController.text,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Incoming Call...',
              style: TextStyle(color: Colors.blue, fontSize: 18),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CallActionCircle(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onTap: _endCall,
                  ),
                  _CallActionCircle(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onTap: _answerCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCallUI() {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            _nameController.text,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            '00:04',
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
          const Spacer(),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            children: [
              _CallTool(icon: Icons.mic_off, label: 'Mute'),
              _CallTool(icon: Icons.dialpad, label: 'Keypad'),
              _CallTool(icon: Icons.volume_up, label: 'Speaker'),
              _CallTool(icon: Icons.add, label: 'Add Call'),
              _CallTool(icon: Icons.video_call, label: 'FaceTime'),
              _CallTool(icon: Icons.contact_page, label: 'Contacts'),
            ],
          ),
          const SizedBox(height: 64),
          _CallActionCircle(
            icon: Icons.call_end,
            color: Colors.red,
            label: 'End',
            onTap: _endCall,
            large: true,
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _CallActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool large;

  const _CallActionCircle({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: large ? 80 : 70,
            height: large ? 80 : 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: large ? 40 : 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _CallTool extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CallTool({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
