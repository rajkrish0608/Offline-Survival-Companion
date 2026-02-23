import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:logger/logger.dart';

class ShakeDetectorService {
  final EmergencyService _emergencyService;
  final Logger _logger = Logger();
  
  StreamSubscription? _subscription;
  bool _isActive = false;
  
  // G-force threshold for a shake
  static const double _shakeThresholdGravity = 2.7;
  static const int _shakeSlopTimeMs = 500;
  static const int _shakeCountResetTimeMs = 3000;
  
  int _shakeCount = 0;
  int _lastShakeTimestamp = 0;

  ShakeDetectorService(this._emergencyService);

  void start() {
    if (_isActive) return;
    _isActive = true;
    
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double gX = event.x / 9.80665;
      double gY = event.y / 9.80665;
      double gZ = event.z / 9.80665;

      // g-force weight
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > _shakeThresholdGravity) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Ignore shake events too close together
        if (_lastShakeTimestamp + _shakeSlopTimeMs > now) {
          return;
        }

        // Reset shake count after a while
        if (_lastShakeTimestamp + _shakeCountResetTimeMs < now) {
          _shakeCount = 0;
        }

        _lastShakeTimestamp = now;
        _shakeCount++;

        if (_shakeCount >= 3) {
          _logger.w('Device shake detected! Triggering SOS.');
          _triggerSOS();
          _shakeCount = 0;
        }
      }
    });
    
    _logger.i('Shake detection service started');
  }

  void stop() {
    _subscription?.cancel();
    _isActive = false;
    _logger.i('Shake detection service stopped');
  }

  void _triggerSOS() {
    // We trigger the emergency service. 
    // Usually we would need current userId, but for local alert we can just call it with a placeholder.
    _emergencyService.activateSOS(userId: 'local_user');
  }

  bool get isActive => _isActive;
}
