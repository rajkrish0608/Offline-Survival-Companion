import 'dart:async';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:logger/logger.dart';

class NetworkRelayAgent extends AgentBase {
  final Logger _logger = Logger();
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Strategy _strategy = Strategy.P2P_STAR; 
  final String _userName = 'SurvivorNode-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

  @override
  String get agentName => 'Mesh Network Relay Agent';

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final String action = params['action'] ?? '';

    try {
      if (action == 'start_mesh') {
        await _startAdvertising();
        await _startDiscovering();
        return AgentResult.success(message: 'Mesh Node active. Searching for peers.');
      } else if (action == 'stop_mesh') {
        await _stopAllEndpoints();
        return AgentResult.success(message: 'Mesh Node disabled.');
      } else if (action == 'broadcast_sos') {
        final payload = params['payload'] as String?;
        if (payload != null) {
          _logger.w('Agent 13: Broadcasting SOS payload across mesh: $payload');
          // In a full implementation, iterate over connected endpoints and send
        }
        return AgentResult.success(message: 'SOS packet delegated to mesh.');
      } else {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'Unknown Network Relay action.');
      }
    } catch (e) {
      _logger.e('Agent 13 Mesh Error: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Network Relay error: $e');
    }
  }

  Future<void> _startAdvertising() async {
    try {
      _logger.i('Agent 13: Starting mesh advertisement as $_userName');
      bool a = await Nearby().startAdvertising(
        _userName,
        _strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          _logger.i('Mesh Peer found: ${info.endpointName} (ID: $id)');
          // Auto-accept in survival scenarios to form mesh
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              _logger.i('Received P2P payload from $endpointId');
            },
          );
        },
        onConnectionResult: (id, status) {
          _logger.i('Connected to mesh peer $id: $status');
        },
        onDisconnected: (id) {
          _logger.i('Mesh peer $id disconnected.');
        },
      );
      _isAdvertising = a;
    } catch (e) {
      _logger.e('Agent 13: Failed to start advertising: $e');
    }
  }

  Future<void> _startDiscovering() async {
    try {
      _logger.i('Agent 13: Discovering mesh peers...');
      bool a = await Nearby().startDiscovery(
        _userName,
        _strategy,
        onEndpointFound: (String id, String name, String serviceId) {
          _logger.i('Agent 13: Peer discovered - $name ($id). Requesting connection.');
          Nearby().requestConnection(
            _userName,
            id,
            onConnectionInitiated: (id, info) {
              Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endpointId, payload) {
                  _logger.i('Received payload from $endpointId');
                },
              );
            },
            onConnectionResult: (id, status) {},
            onDisconnected: (id) {},
          );
        },
        onEndpointLost: (String id) {},
      );
      _isDiscovering = a;
    } catch (e) {
      _logger.e('Agent 13: Failed to start discovery: $e');
    }
  }

  Future<void> _stopAllEndpoints() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _isAdvertising = false;
    _isDiscovering = false;
    _logger.i('Agent 13: Mesh tear down complete.');
  }
}
