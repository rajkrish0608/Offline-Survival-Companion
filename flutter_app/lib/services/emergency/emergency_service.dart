import 'package:flutter_sms/flutter_sms.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:torch_light/torch_light.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:offline_survival_companion/core/constants/app_constants.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:logger/logger.dart';

class EmergencyService {
  final LocalStorageService _storageService;
  final Battery _battery = Battery();
  final Logger _logger = Logger();

  bool _sosActive = false;
  DateTime? _sosStartTime;
  String? _lastKnownPosition;
  List<String> _emergencyContacts = [];

  EmergencyService({LocalStorageService? storageService})
    : _storageService = storageService ?? LocalStorageService();

  Future<void> initialize() async {
    try {
      await _requestLocationPermission();
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

      _logger.i('SOS deactivated by user $userId');
    } catch (e) {
      _logger.e('Failed to deactivate SOS: $e');
    }
  }

  /// Enable device flashlight
  Future<void> enableFlashlight() async {
    try {
      // await TorchLight.enableTorch();
      _logger.i('Flashlight enabled (simulated)');
    } catch (e) {
      _logger.e('Failed to enable flashlight: $e');
    }
  }

  /// Disable device flashlight
  Future<void> disableFlashlight() async {
    try {
      // await TorchLight.disableTorch();
      _logger.i('Flashlight disabled (simulated)');
    } catch (e) {
      _logger.e('Failed to disable flashlight: $e');
    }
  }

  /// Check if flashlight is available
  Future<bool> isFlashlightAvailable() async {
    try {
      // return await TorchLight.isTorchAvailable();
      return false;
    } catch (e) {
      return false;
    }
  }

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
      // If permission denied or timeout, try last known
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
      // Queue for retry later
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
    buffer.writeln('Battery: ${getBatteryLevel()}%');

    if (customMessage.isNotEmpty) {
      buffer.writeln('Message: $customMessage');
    }

    buffer.writeln('— Sent via Offline Survival Companion');
    return buffer.toString();
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_sosActive) {
      await deactivateSOS(userId: 'unknown');
    }
  }
}
