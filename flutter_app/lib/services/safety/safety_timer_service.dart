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
  bool _isJourneyMode = false;
  int _missedCheckIns = 0;
  int _checkInIntervalSeconds = 0;

  SafetyTimerService(this._emergencyService);

  bool get isActive => _isActive;
  bool get isJourneyMode => _isJourneyMode;
  int get remainingSeconds => _remainingSeconds;
  int get missedCheckIns => _missedCheckIns;

  void startTimer({
    required int seconds,
    required String pin,
    required String userId,
    bool isJourneyMode = false,
  }) {
    if (_isActive) return;

    _remainingSeconds = seconds;
    _checkInIntervalSeconds = seconds;
    _pin = pin;
    _userId = userId;
    _isActive = true;
    _isJourneyMode = isJourneyMode;
    _missedCheckIns = 0;
    notifyListeners();

    _startInternalTimer();
    
    _logger.i('Safety Timer started for $seconds seconds (Journey Mode: $isJourneyMode)');
  }

  void _startInternalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _handleTimerExpiraton();
      }
    });
  }

  void _handleTimerExpiraton() {
    if (!_isJourneyMode) {
      _triggerSOS('Automated SOS: Safety Check-in Timer expired.');
    } else {
      _missedCheckIns++;
      _logger.w('Journey check-in missed! Count: $_missedCheckIns');
      
      if (_missedCheckIns >= 2) {
        _triggerSOS('Automated SOS: Journey Check-in missed twice. Escalating.');
      } else {
        // Give 1 more minute for the second check-in attempt (loud alert phase)
        _remainingSeconds = 60; 
        notifyListeners();
        _logger.i('Entering FINAL check-in warning phase (60s)');
      }
    }
  }

  void acknowledgeCheckIn() {
    if (!_isActive || !_isJourneyMode) return;
    
    _missedCheckIns = 0;
    _remainingSeconds = _checkInIntervalSeconds;
    notifyListeners();
    _logger.i('Journey check-in acknowledged. Timer reset.');
  }

  void stopTimer(String pin) {
    if (pin == _pin) {
      _timer?.cancel();
      _isActive = false;
      _isJourneyMode = false;
      _remainingSeconds = 0;
      _pin = null;
      _missedCheckIns = 0;
      notifyListeners();
      _logger.i('Safety Timer stopped successfully with PIN');
    } else {
      _logger.w('Failed attempt to stop Safety Timer with incorrect PIN');
      throw Exception('Incorrect PIN');
    }
  }

  Future<void> _triggerSOS(String message) async {
    _timer?.cancel();
    _isActive = false;
    _isJourneyMode = false;
    notifyListeners();
    
    if (_userId != null) {
      _logger.e('Safety Timer EXPIRED. Triggering SOS for user $_userId');
      await _emergencyService.activateSOS(
        userId: _userId!,
        customMessage: message,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
