import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_survival_companion/services/safety/safety_timer_service.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SafetyTimerScreen extends StatefulWidget {
  const SafetyTimerScreen({super.key});

  @override
  State<SafetyTimerScreen> createState() => _SafetyTimerScreenState();
}

class _SafetyTimerScreenState extends State<SafetyTimerScreen> {
  final TextEditingController _pinController = TextEditingController();
  int _minutes = 20;
  bool _showPinGate = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _handleStart() {
    final state = context.read<AppBloc>().state;
    if (state is! AppReady) return;

    if (_pinController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a 4-digit PIN')),
      );
      return;
    }

    context.read<SafetyTimerService>().startTimer(
          seconds: _minutes * 60,
          pin: _pinController.text,
          userId: state.userId,
        );
    
    _pinController.clear();
  }

  void _handleStop() {
    try {
      context.read<SafetyTimerService>().stopTimer(_pinController.text);
      _pinController.clear();
      setState(() => _showPinGate = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Check-in Timer')),
      body: Consumer<SafetyTimerService>(
        builder: (context, service, child) {
          if (service.isActive) {
            return _buildActiveView(service);
          }
          return _buildSetupView();
        },
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your loved ones informed if you don\'t check in by a certain time.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _minutes.toDouble(),
            min: 1,
            max: 120,
            divisions: 119,
            label: '$_minutes min',
            activeColor: AppTheme.accentBlue,
            onChanged: (v) => setState(() => _minutes = v.toInt()),
          ),
          Center(
            child: Text(
              '$_minutes Minutes',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 48),
          const Text('Set a Deactivation PIN:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '4-Digit PIN',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _handleStart,
              icon: const Icon(Icons.play_circle_filled),
              label: const Text('Start Safety Watch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _infoCard('If the timer expires, an SOS with your location is sent via SMS automatically.'),
        ],
      ),
    );
  }

  Widget _buildActiveView(SafetyTimerService service) {
    final minutes = service.remainingSeconds ~/ 60;
    final seconds = service.remainingSeconds % 60;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 64),
        color: AppTheme.primaryDark,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.green),
            const SizedBox(height: 32),
            const Text(
              'Safety Watch Active',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w200),
            ),
            const SizedBox(height: 64),
            if (!_showPinGate)
              SizedBox(
                width: 200,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPinGate = true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                  child: const Text('I am Safe (Stop)'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    TextField(
                      controller: _pinController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 16),
                      decoration: const InputDecoration(hintText: 'PIN'),
                      onChanged: (v) {
                        if (v.length == 4) _handleStop();
                      },
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showPinGate = false),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.accentBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppTheme.accentBlue, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
