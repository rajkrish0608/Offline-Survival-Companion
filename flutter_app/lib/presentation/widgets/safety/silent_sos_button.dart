import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';

class SilentSOSButton extends StatefulWidget {
  final double size;
  const SilentSOSButton({super.key, this.size = 120});

  @override
  State<SilentSOSButton> createState() => _SilentSOSButtonState();
}

class _SilentSOSButtonState extends State<SilentSOSButton> with SingleTickerProviderStateMixin {
  bool _isHolding = false;
  double _progress = 0.0;
  Timer? _timer;
  late AnimationController _controller;
  
  // 5 second hold/release window logic
  // Phase 1: Holding (Filling up)
  // Phase 2: Released (Countdown to alert)
  
  bool _isCountdownActive = false;
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          _progress = _controller.value;
        });
      });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isCountdownActive) return;
    
    setState(() {
      _isHolding = true;
      _progress = 0.0;
    });
    _controller.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails details) {
    if (_isCountdownActive) return;
    
    _controller.stop();
    if (_progress < 0.9) {
      // Released too early, reset
      setState(() {
        _isHolding = false;
        _progress = 0.0;
      });
    } else {
      // Successfully "armed"
      _startSafetyLock();
    }
  }

  void _onTapCancel() {
    if (_isCountdownActive) return;
    _controller.stop();
    setState(() {
      _isHolding = false;
      _progress = 0.0;
    });
  }

  void _startSafetyLock() {
    setState(() {
      _isHolding = false;
      _isCountdownActive = true;
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _progress = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Alert Cancelled')),
    );
  }

  void _triggerSOS() {
    setState(() => _isCountdownActive = false);
    context.read<EmergencyService>().activateSOS(userId: 'local_user');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Triggered!', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _isCountdownActive ? 1.0 : _progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isCountdownActive ? Colors.red : Colors.orange,
                  ),
                ),
              ),
              Container(
                width: widget.size - 20,
                height: widget.size - 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCountdownActive ? Colors.red : Colors.orange.withOpacity(0.2),
                  border: Border.all(
                    color: _isCountdownActive ? Colors.red : Colors.orange,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: _isCountdownActive 
                    ? Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isHolding ? Icons.security : Icons.touch_app,
                        size: 40,
                        color: Colors.orange,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isCountdownActive 
              ? 'ALERTTING IN $_countdown...' 
              : (_isHolding ? 'HOLD STEADY' : 'HOLD IF UNSAFE'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isCountdownActive ? Colors.red : Colors.white70,
          )
        ),
        if (_isCountdownActive)
          TextButton(
            onPressed: _cancelSOS,
            child: const Text('CANCEL', style: TextStyle(color: Colors.blue)),
          ),
      ],
    );
  }
}
