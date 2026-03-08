import 'dart:async';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:logger/logger.dart';

class SituationAwarenessAgent extends AgentBase {
  final Logger _logger = Logger();
  final Battery _battery = Battery();
  
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  Timer? _batteryTimer;
  bool _isMonitoring = false;

  @override
  String get agentName => 'Situation Awareness Agent';

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _logger.i('Agent 4 (Situation Awareness) active. Monitoring sensors...');

    // Monitor Sudden Drops / Falls (Accelerometer Anomaly)
    _accelSubscription = userAccelerometerEventStream(samplingPeriod: const Duration(seconds: 1)).listen((event) {
      // Calculate magnitude of acceleration vector
      final magnitude = event.x.abs() + event.y.abs() + event.z.abs();
      if (magnitude > 30.0) {
        _logger.w('Agent 4: Massive acceleration detected ($magnitude) - Possible fall or collision!');
        _triggerAnomalyEvent('Sudden impact or fall detected.');
      }
    });

    // Monitor Battery Level Anomaly
    _batteryTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final level = await _battery.batteryLevel;
      if (level <= 15) {
        _logger.w('Agent 4: Critical battery detected ($level%).');
        _triggerAnomalyEvent('Critical battery: $level%. Recommend generating final location ping.');
      }
    });
  }

  void stopMonitoring() {
    _accelSubscription?.cancel();
    _batteryTimer?.cancel();
    _isMonitoring = false;
    _logger.i('Agent 4 monitoring halted.');
  }

  void _triggerAnomalyEvent(String reason) {
    // In a full implementation, this routes back to AgentOrchestrator to trigger EmergencyResponse
    // or SmartComms to send a "Low Battery / Last Known Location" ping.
    updateStatus(AgentStatus.running);
    _logger.i('Anomaly triggered: $reason');
    updateStatus(AgentStatus.idle);
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    final action = params['action'] as String?;

    if (action == 'start') {
      await startMonitoring();
      return AgentResult.success(message: 'Started background situation monitoring.');
    } else if (action == 'stop') {
      stopMonitoring();
      return AgentResult.success(message: 'Stopped background situation monitoring.');
    } else {
      // One-off snapshot
      final level = await _battery.batteryLevel;
      return AgentResult.success(
        message: 'Situation Snapshot',
        data: {'batteryLevel': level, 'monitoringActive': _isMonitoring},
      );
    }
  }
}
