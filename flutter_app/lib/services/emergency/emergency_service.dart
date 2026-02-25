import 'dart:async';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/services/safety/evidence_service.dart';
import 'package:offline_survival_companion/services/network/peer_mesh_service.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class EmergencyService extends ChangeNotifier {
  final EvidenceService? _evidenceService;
  final PeerMeshService? _peerMeshService;
  final Battery _battery = Battery();
  final Logger _logger = Logger();

  bool _sosActive = false;
  bool _flashlightOn = false;
  bool _isSurvivalMode = false;
  DateTime? _sosStartTime;
  String? _lastKnownPosition;
  List<String> _emergencyContacts = [];
  final LocalStorageService _storageService;

  EmergencyService({
    LocalStorageService? storageService,
    EvidenceService? evidenceService,
    PeerMeshService? peerMeshService,
  })  : _storageService = storageService ?? LocalStorageService(),
        _evidenceService = evidenceService,
        _peerMeshService = peerMeshService;

  Future<void> initialize() async {
    try {
      _logger.i('Emergency service initialized');
    } catch (e) {
      _logger.e('Emergency service initialization failed: $e');
    }
  }

  /// Activate SOS mode
  Future<void> activateSOS({
    required String userId,
    String customMessage = '',
  }) async {
    try {
      _sosActive = true;
      _sosStartTime = DateTime.now();

      // Enable wake lock to keep screen on
      await WakelockPlus.enable();

      // Request location permission if not already granted
      await _requestLocationPermission();

      // Get current location
      final position = await _getCurrentLocation();
      _lastKnownPosition = '${position.latitude},${position.longitude}';

      // Get emergency contacts
      _emergencyContacts = await _getEmergencyContacts(userId);

      // Activate flashlight
      await enableFlashlight();

      // Send SMS to all emergency contacts
      await _sendEmergencySMS(
        position: position,
        customMessage: customMessage,
        userName: await _getUserName(userId),
      );

      // 3. Capture Auto-Evidence
      if (_evidenceService != null) {
        unawaited(_evidenceService!.captureEvidence(userId: userId));
      }

      // 4. Start Offline P2P Broadcast
      if (_peerMeshService != null) {
        final sosPayload = {
          'type': 'sos',
          'userId': userId,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'customMessage': customMessage,
        };
        unawaited(_peerMeshService!.broadcastSOS(sosPayload));
      }

      _logger.w('SOS activated by user $userId');
    } catch (e) {
      _logger.e('Failed to activate SOS: $e');
      rethrow;
    }
  }

  /// Deactivate SOS mode
  Future<void> deactivateSOS({required String userId}) async {
    try {
      _sosActive = false;
      _sosStartTime = null;

      // Disable wake lock
      await WakelockPlus.disable();

      // Turn off flashlight
      await disableFlashlight();

      // Send all-clear SMS
      await _sendAllClearSMS(userId);

      // Stop Evidence Capture
      if (_evidenceService != null) {
        await _evidenceService!.stopCapture();
      }

      // Stop P2P Broadcast
      if (_peerMeshService != null) {
        await _peerMeshService!.stopAll();
      }

      _logger.i('SOS deactivated by user $userId');
    } catch (e) {
      _logger.e('Failed to deactivate SOS: $e');
    }
  }

  /// Enable device flashlight (real hardware)
  Future<void> enableFlashlight() async {
    try {
      final available = await isTorchAvailable();
      if (!available) {
        _logger.w('Torch not available on this device');
        return;
      }

      // Request camera permission as it's often required for torch control
      final permission = await _requestCameraPermission();
      if (!permission) {
        _logger.e('Camera permission denied - cannot enable flashlight');
        return;
      }

      await TorchLight.enableTorch();
      _flashlightOn = true;
      _logger.i('Flashlight enabled');
    } catch (e) {
      _logger.e('Failed to enable flashlight: $e');
    }
  }

  Future<bool> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      _logger.e('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Disable device flashlight
  Future<void> disableFlashlight() async {
    try {
      if (_flashlightOn) {
        await TorchLight.disableTorch();
        _flashlightOn = false;
        _logger.i('Flashlight disabled');
      }
    } catch (e) {
      _logger.e('Failed to disable flashlight: $e');
    }
  }

  /// Toggle flashlight on/off
  Future<bool> toggleFlashlight() async {
    if (_flashlightOn) {
      await disableFlashlight();
    } else {
      await enableFlashlight();
    }
    return _flashlightOn;
  }

  /// Check if torch is available on this device
  Future<bool> isTorchAvailable() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      return false;
    }
  }

  /// Backward-compat alias
  Future<bool> isFlashlightAvailable() => isTorchAvailable();

  bool get isFlashlightOn => _flashlightOn;

  /// Get current battery level
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      _logger.e('Failed to get battery level: $e');
      return 0;
    }
  }

  /// Check if battery is in low power mode
  Future<bool> isLowBattery() async {
    final level = await getBatteryLevel();
    return level < (AppConstants.lowBatteryThreshold * 100).toInt();
  }

  /// Get SOS status
  bool get isSosActive => _sosActive;

  bool get isSurvivalMode => _isSurvivalMode;

  void setSurvivalMode(bool value) {
    _isSurvivalMode = value;
    _logger.w('Survival Mode (Battery Saver) ${value ? 'ENABLED' : 'DISABLED'}');
    notifyListeners();
  }

  /// Get time elapsed since SOS activation
  Duration? get sosElapsedTime {
    if (!_sosActive || _sosStartTime == null) return null;
    return DateTime.now().difference(_sosStartTime!);
  }

  /// Get last known position
  String? get lastKnownPosition => _lastKnownPosition;

  // ==================== Private Methods ====================

  Future<Position> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _logger.e('Failed to get current location: $e');
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied) {
        throw Exception('Location permission not granted');
      }
      throw Exception('Could not get current location: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<List<String>> _getEmergencyContacts(String userId) async {
    try {
      final contacts = await _storageService.getEmergencyContacts(userId);
      return contacts.map((c) => c['phone'] as String).toList();
    } catch (e) {
      _logger.e('Failed to get emergency contacts: $e');
      return [];
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final user = await _storageService.getUser(userId);
      return user?['name'] ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  Future<void> _sendEmergencySMS({
    required Position position,
    required String customMessage,
    required String userName,
  }) async {
    if (_emergencyContacts.isEmpty) {
      _logger.w('No emergency contacts available for SMS');
      return;
    }

    try {
      final message = _buildSOSMessage(
        position: position,
        customMessage: customMessage,
        userName: userName,
      );

      final String result = await sendSMS(
        recipients: _emergencyContacts,
        message: message,
      );

      _logger.i('SOS SMS sent: $result');
    } catch (e) {
      _logger.e('Failed to send emergency SMS: $e');
    }
  }

  Future<void> _sendAllClearSMS(String userId) async {
    if (_emergencyContacts.isEmpty) return;

    try {
      final userName = await _getUserName(userId);
      final message =
          '✓ All clear - $userName has ended emergency mode. Time: ${DateTime.now().toIso8601String()}';

      await sendSMS(recipients: _emergencyContacts, message: message);
      _logger.i('All-clear SMS sent');
    } catch (e) {
      _logger.e('Failed to send all-clear SMS: $e');
    }
  }

  String _buildSOSMessage({
    required Position position,
    required String customMessage,
    required String userName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🆘 EMERGENCY — $userName activated SOS');
    buffer.writeln('Location: ${position.latitude}, ${position.longitude}');
    buffer.writeln(
      'Maps: https://maps.google.com/?q=${position.latitude},${position.longitude}',
    );
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');

    if (customMessage.isNotEmpty) {
      buffer.writeln('Message: $customMessage');
    }

    buffer.writeln('— Sent via Offline Survival Companion');
    return buffer.toString();
  }

  /// Clean up resources
  @override
  Future<void> dispose() async {
    if (_sosActive) {
      await deactivateSOS(userId: 'unknown');
    }
  }
}
