import 'dart:convert';
import 'dart:async';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Handles offline peer-to-peer (P2P) communication for
/// BLE and Wi-Fi Direct using flutter_nearby_connections.
class PeerMeshService {
  static const _hardwareChannel = MethodChannel('com.example.offline_survival_companion/hardware');
  final Logger _logger = Logger();
  late NearbyService nearbyService;

  bool _isBroadcasting = false;
  bool _isDiscovering = false;
  Map<String, dynamic>? _pendingSosPayload;

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
            // Aggressive auto-connect: always invite discovered peers immediately
            // so we form a background mesh without user interaction
            _logger.i("Auto-inviting discovered peer: ${element.deviceName}");
            nearbyService.invitePeer(deviceID: element.deviceId, deviceName: element.deviceName);
            break;
          case SessionState.connecting:
            _logger.i("Connecting to peer: ${element.deviceName}...");
            break;
          case SessionState.connected:
            if (!_connectedDevices.any((d) => d.deviceId == element.deviceId)) {
              _connectedDevices.add(element);
              _logger.i("Connected to peer: ${element.deviceName}");
              
              // If we have a pending SOS, send it immediately upon connection
              if (_pendingSosPayload != null) {
                final jsonString = jsonEncode(_pendingSosPayload);
                nearbyService.sendMessage(element.deviceId, jsonString);
                _logger.w('🚀 Sent pending SOS payload to newly connected peer: ${element.deviceName}');
              }
            }
            break;
            }
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
      // Must explicitly request permissions before starting Mesh radios
      final locStatus = await Permission.location.request();
      final blStatus = await Permission.bluetooth.request();
      final blConnectStatus = await Permission.bluetoothConnect.request();
      final blScanStatus = await Permission.bluetoothScan.request();
      final blAdvertiseStatus = await Permission.bluetoothAdvertise.request();

      if (!locStatus.isGranted || 
          !(blStatus.isGranted || blConnectStatus.isGranted || blScanStatus.isGranted || blAdvertiseStatus.isGranted)) {
        _logger.e('Failed to broadcast SOS: Mesh permissions denied by user.');
        return;
      }

      // Proactively check and prompt hardware toggles if radios are OFF
      try {
        final bool isBtOn = await _hardwareChannel.invokeMethod('isBluetoothOn') ?? false;
        if (!isBtOn) {
          _logger.w('Bluetooth is off. Prompting user to enable it.');
          await _hardwareChannel.invokeMethod('turnOnBluetooth');
          // Short delay to allow user to respond to prompt
          await Future.delayed(const Duration(seconds: 2));
        }
        
        final bool isWifiOn = await _hardwareChannel.invokeMethod('isWifiOn') ?? false;
        if (!isWifiOn) {
          _logger.w('Wi-Fi is off. Prompting user to enable it in Settings.');
          await _hardwareChannel.invokeMethod('openWifiSettings');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        _logger.e('Failed to invoke hardware channel: $e');
      }

      if (subscription == null) {
        await initialize();
      }

      await nearbyService.startAdvertisingPeer();
      
      // Also start discovering to maximize connection chances
      if (!_isDiscovering) {
        await nearbyService.startBrowsingForPeers();
        _isDiscovering = true;
      }
      
      _isBroadcasting = true;
      _pendingSosPayload = sosPayload; // Store for future connections
      _logger.w('🔥 [MESH] Broadcasting offline SOS via BLE/WiFi-Direct...');

      // Immediately send the payload to all already connected devices
      final jsonString = jsonEncode(sosPayload);
      if (_connectedDevices.isNotEmpty) {
        for (var device in _connectedDevices) {
          nearbyService.sendMessage(device.deviceId, jsonString);
          _logger.w('🚀 Sent SOS payload instantaneously to ${device.deviceName}');
        }
      } else {
        _logger.w('No devices connected yet. Payload queued and will send automatically upon connection.');
      }
    } catch (e) {
      _logger.e('Failed to start P2P broadcast: $e');
    }
  }

  Future<void> startDiscovering() async {
    if (_isDiscovering) return;

    try {
      // Must explicitly request permissions before starting Mesh radios
      final locStatus = await Permission.location.request();
      final blStatus = await Permission.bluetooth.request();
      final blConnectStatus = await Permission.bluetoothConnect.request();
      final blScanStatus = await Permission.bluetoothScan.request();

      if (!locStatus.isGranted || 
          !(blStatus.isGranted || blConnectStatus.isGranted || blScanStatus.isGranted)) {
        _logger.w('Passive Mesh discovery skipped: Permissions not granted.');
        return;
      }

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
      
      _pendingSosPayload = null;
      
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
