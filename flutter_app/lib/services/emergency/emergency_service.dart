import 'dart:async';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/services/safety/evidence_service.dart';
import 'package:offline_survival_companion/services/network/peer_mesh_service.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class EmergencyService extends ChangeNotifier {
  final EvidenceService? _evidenceService;
  final PeerMeshService? _peerMeshService;
  final Battery _battery = Battery();
  final Logger _logger = Logger();
  final LocalStorageService _storageService;

  bool _sosActive = false;
  bool _flashlightOn = false;
  DateTime? _sosStartTime;
  List<String> _emergencyContacts = [];

  EmergencyService({
    LocalStorageService? storageService,
    EvidenceService? evidenceService,
    PeerMeshService? peerMeshService,
  })  : _storageService = storageService ?? LocalStorageService(),
        _evidenceService = evidenceService,
        _peerMeshService = peerMeshService;

  Future<void> activateSOS({
    required String userId,
    String customMessage = '',
  }) async {
    try {
      _sosActive = true;
      _sosStartTime = DateTime.now();

      await WakelockPlus.enable();
      await _requestLocationPermission();

      final position = await _getCurrentLocation();
      _emergencyContacts = await _getEmergencyContacts(userId);
      await enableFlashlight();

      // Requirement #1: Personalized SOS Message with Name
      final userName = await _getUserName(userId);
      final sosMessage = _buildSOSMessage(
        position: position,
        customMessage: customMessage,
        userName: userName,
      );

      // Send SMS to contacts
      await _sendEmergencySMSDirect(message: sosMessage);

      // Requirement #5: Archive Exact SOS Message (Immutable Record)
      await _storageService.archiveSosMessage(
        id: const Uuid().v4(),
        userId: userId,
        fullMessage: sosMessage,
        lat: position.latitude,
        lng: position.longitude,
      );

      // Requirement #3: Log Activity for Analytics
      await _storageService.logActivity(
        id: const Uuid().v4(),
        userId: userId,
        feature: 'SOS',
      );

      if (_evidenceService != null) {
        unawaited(_evidenceService!.captureEvidence(userId: userId));
      }

      // P2P / MESH BROADCAST (Requirement: Keep P2P)
      if (_peerMeshService != null) {
        final sosPayload = {
          'type': 'sos',
          'userId': userId,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };
        unawaited(_peerMeshService!.broadcastSOS(sosPayload));
      }

      _logger.w('SOS activated by $userName');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to activate SOS: $e');
      rethrow;
    }
  }

  String _buildSOSMessage({
    required Position position,
    required String customMessage,
    required String userName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('[EMERGENCY] $userName has triggered an SOS.');
    buffer.writeln('Location: ${position.latitude}, ${position.longitude}');
    buffer.writeln('Maps: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}');
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');

    if (customMessage.isNotEmpty) {
      buffer.writeln('Message: $customMessage');
    }
    buffer.writeln('— Sent via Offline Survival Companion');
    return buffer.toString();
  }

  Future<String> _getUserName(String userId) async {
    final user = await _storageService.getUser(userId);
    return user?['name'] ?? 'User';
  }

  Future<List<String>> _getEmergencyContacts(String userId) async {
    final contacts = await _storageService.getEmergencyContacts(userId);
    return contacts.map((c) => c['phone'] as String).toList();
  }

  Future<void> _sendEmergencySMSDirect({required String message}) async {
    if (_emergencyContacts.isEmpty) return;
    try {
      await sendSMS(recipients: _emergencyContacts, message: message);
    } catch (e) {
      _logger.e('SMS Send Error: $e');
    }
  }

  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  Future<void> _requestLocationPermission() async {
    await Geolocator.requestPermission();
  }

  Future<void> enableFlashlight() async {
    try {
      await TorchLight.enableTorch();
      _flashlightOn = true;
    } catch (_) {}
  }

  Future<void> disableFlashlight() async {
    try {
      await TorchLight.disableTorch();
      _flashlightOn = false;
    } catch (_) {}
  }

  bool get isSosActive => _sosActive;
}