import 'dart:async';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:environment_sensors/environment_sensors.dart';
import 'package:logger/logger.dart';

class WeatherPredictionAgent extends AgentBase {
  final Logger _logger = Logger();
  final environmentSensors = EnvironmentSensors();

  StreamSubscription<double>? _pressureSubscription;
  final List<double> _pressureHistory = [];
  bool _isMonitoring = false;

  @override
  String get agentName => 'Weather Prediction Agent';

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    bool hasBarometer = await environmentSensors.getSensorAvailable(SensorType.Pressure);
    if (!hasBarometer) {
      _logger.w('Agent 14: Barometer sensor not available on this device. Weather prediction disabled.');
      return;
    }

    _isMonitoring = true;
    _logger.i('Agent 14 (Weather Prediction) active. Monitoring atmospheric pressure...');

    _pressureSubscription = environmentSensors.pressure.listen((pressure) {
      _logger.d('Agent 14: Current pressure: $pressure hPa');
      _pressureHistory.add(pressure);

      // Keep only last 12 readings (e.g., if polled every 5 mins, this is 1 hour of data)
      if (_pressureHistory.length > 12) {
        _pressureHistory.removeAt(0);
      }

      _analyzePressureTrend();
    });
  }

  void _analyzePressureTrend() {
    if (_pressureHistory.length < 5) return; // Need enough data points

    final first = _pressureHistory.first;
    final current = _pressureHistory.last;
    final drop = first - current;

    // A drop > 3 hPa in a short period indicates a strong low-pressure system (storm approaching)
    if (drop >= 3.0) {
      _logger.w('Agent 14: Rapid barometric pressure drop detected ($drop hPa). Storm likely approaching.');
      _triggerWeatherAlert('Severe Storm Warning: Rapid atmospheric pressure drop detected. Seek shelter immediately.');
    } else if (drop >= 1.5) {
      _logger.i('Agent 14: Moderate pressure drop. Weather is degrading.');
    }
  }

  void stopMonitoring() {
    _pressureSubscription?.cancel();
    _isMonitoring = false;
    _pressureHistory.clear();
    _logger.i('Agent 14 monitoring stopped.');
  }

  void _triggerWeatherAlert(String advisory) {
    updateStatus(AgentStatus.running);
    _logger.i('WEATHER ALERT TRIGGERED: $advisory');
    // In production, this would trigger a local push notification via Agent 11 (Scheduler/Notifier)
    updateStatus(AgentStatus.idle);
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    final action = params['action'] as String?;

    if (action == 'start') {
      await startMonitoring();
      return AgentResult.success(message: 'Started background weather monitoring.');
    } else if (action == 'stop') {
      stopMonitoring();
      return AgentResult.success(message: 'Stopped background weather monitoring.');
    } else if (action == 'snapshot') {
      return AgentResult.success(
        message: 'Weather Snapshot',
        data: {
          'current_pressure': _pressureHistory.isNotEmpty ? _pressureHistory.last : 'N/A',
          'trend': _pressureHistory.length >= 2 
              ? (_pressureHistory.last < _pressureHistory.first ? 'Falling (Bad Weather)' : 'Stable/Rising') 
              : 'Gathering data',
        },
      );
    } else {
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Unknown weather prediction agent action.');
    }
  }
}
