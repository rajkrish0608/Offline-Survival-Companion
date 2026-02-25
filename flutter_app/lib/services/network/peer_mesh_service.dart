import 'dart:convert';
import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:logger/logger.dart';

/// Handles offline peer-to-peer (P2P) communication for
/// BLE and Wi-Fi Direct using flutter_nearby_connections.
class PeerMeshService {
  final Logger _logger = Logger();
  late NearbyService nearbyService;

  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  Function(Map<String, dynamic>)? onSosReceived;
  final List<Device> _connectedDevices = [];

  StreamSubscription? subscription;
  StreamSubscription? receivedDataSubscription;

  PeerMeshService() {
    nearbyService = NearbyService();
  }

  Future<void> initialize() async {
    await nearbyService.init(
      serviceType: 'mpconnection',
      deviceName: 'SurvivalNode_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', 
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning) {
          _logger.i('NearbyService running successfully.');
        } else {
           _logger.e('NearbyService failed to start.');
        }
      },
    );
    
    // Listen for device state changes
    subscription = nearbyService.stateChangedSubscription(callback: (devicesList) {
      devicesList.forEach((element) {
        _logger.i("Device state changed: ${element.deviceName} is ${element.state}");
        
        switch (element.state) {
          case SessionState.notConnected:
            _connectedDevices.removeWhere((d) => d.deviceId == element.deviceId);
            break;
          case SessionState.connected:
            if (!_connectedDevices.any((d) => d.deviceId == element.deviceId)) {
              _connectedDevices.add(element);
            }
            break;
          case SessionState.connecting:
            break;
        }
      });
    });

    // Listen for incoming payloads
    receivedDataSubscription = nearbyService.dataReceivedSubscription(callback: (data) {
      try {
        final payload = jsonDecode(data['message']);
        _logger.w('📩 [MESH] Received payload: ${data['message']}');
        if (payload['type'] == 'sos' && onSosReceived != null) {
          onSosReceived!(payload);
        }
      } catch (e) {
        _logger.e('Failed to parse incoming mesh payload: $e');
      }
    });
  }

  Future<void> broadcastSOS(Map<String, dynamic> sosPayload) async {
    if (_isBroadcasting) return;

    try {
      if (subscription == null) {
        await initialize();
      }

      await nearbyService.startAdvertisingPeer();
      _isBroadcasting = true;
      _logger.w('🔥 [MESH] Broadcasting offline SOS via BLE/WiFi-Direct...');

      // Send the payload specifically if we already have connected devices
      final jsonString = jsonEncode(sosPayload);
      for (var device in _connectedDevices) {
        nearbyService.sendMessage(device.deviceId, jsonString);
        _logger.i('Sent SOS payload to ${device.deviceName}');
      }
    } catch (e) {
      _logger.e('Failed to start P2P broadcast: $e');
    }
  }

  Future<void> startDiscovering() async {
    if (_isDiscovering) return;

    try {
      if (subscription == null) {
        await initialize();
      }

      await nearbyService.startBrowsingForPeers();
      _isDiscovering = true;
      _logger.i('📡 [MESH] Scanning for nearby P2P SOS signals...');
    } catch (e) {
      _logger.e('Failed to start P2P discovery: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      if (_isBroadcasting) {
        await nearbyService.stopAdvertisingPeer();
        _isBroadcasting = false;
      }
      if (_isDiscovering) {
        await nearbyService.stopBrowsingForPeers();
        _isDiscovering = false;
      }
      
      for (var device in _connectedDevices) {
        nearbyService.disconnectPeer(deviceID: device.deviceId);
      }
      _connectedDevices.clear();
      
      subscription?.cancel();
      receivedDataSubscription?.cancel();
      subscription = null;
      receivedDataSubscription = null;
      
      _logger.i('🛑 [MESH] P2P services stopped.');
    } catch (e) {
      _logger.e('Failed to stop P2P services: $e');
    }
  }
}
