import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:logger/logger.dart';

class SafetyTimerService extends ChangeNotifier {
  final EmergencyService _emergencyService;
  final Logger _logger = Logger();
  
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isActive = false;
  String? _pin;
  String? _userId;

  SafetyTimerService(this._emergencyService);

  bool get isActive => _isActive;
  int get remainingSeconds => _remainingSeconds;

  void startTimer({
    required int seconds,
    required String pin,
    required String userId,
  }) {
    if (_isActive) return;

    _remainingSeconds = seconds;
    _pin = pin;
    _userId = userId;
    _isActive = true;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _triggerSOS();
      }
    });
    
    _logger.i('Safety Timer started for $seconds seconds');
  }

  void stopTimer(String pin) {
    if (pin == _pin) {
      _timer?.cancel();
      _isActive = false;
      _remainingSeconds = 0;
      _pin = null;
      notifyListeners();
      _logger.i('Safety Timer stopped successfully with PIN');
    } else {
      _logger.w('Failed attempt to stop Safety Timer with incorrect PIN');
      throw Exception('Incorrect PIN');
    }
  }

  Future<void> _triggerSOS() async {
    _timer?.cancel();
    _isActive = false;
    notifyListeners();
    
    if (_userId != null) {
      _logger.e('Safety Timer EXPIRED. Triggering SOS for user $_userId');
      await _emergencyService.activateSOS(
        userId: _userId!,
        customMessage: 'Automated SOS: Safety Check-in Timer expired.',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
