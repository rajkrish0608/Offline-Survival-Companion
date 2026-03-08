import 'dart:async';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:logger/logger.dart';

enum RescuePhase {
  standby,
  alert,
  coordinate,
  guide,
  beacon,
  handoff
}

class RescueCoordinatorAgent extends AgentBase {
  final Logger _logger = Logger();
  RescuePhase _currentPhase = RescuePhase.standby;
  final List<String> _activeRescuers = [];
  Timer? _guidanceTimer;

  @override
  String get agentName => 'Rescue Coordinator Agent';

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String?;
    
    if (command == null) {
      return AgentResult.fail(message: 'No command provided to Rescue Coordinator.');
    }

    updateStatus(AgentStatus.running);
    _logger.i('Agent 12 executing command: $command');

    try {
      switch (command) {
        case 'trigger_alert':
          await _phase1Alert();
          break;
        case 'process_message':
          final sender = params['sender'] as String?;
          final text = params['text'] as String?;
          if (sender != null && text != null) {
            await _phase2Coordinate(sender, text);
          }
          break;
        case 'activate_beacon':
          await _phase4Beacon();
          break;
        case 'rescuer_arrived':
          await _phase5Handoff();
          break;
        default:
          updateStatus(AgentStatus.error);
          return AgentResult.fail(message: 'Unknown Rescue Coordinator command.');
      }
      
      updateStatus(AgentStatus.idle);
      return AgentResult.success(
        message: 'Executed $command in phase ${_currentPhase.name}',
        data: {'phase': _currentPhase.name, 'rescuers_count': _activeRescuers.length},
      );
    } catch (e) {
      _logger.e('Agent 12 failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Rescue coordination error: $e');
    }
  }

  Future<void> _phase1Alert() async {
    _currentPhase = RescuePhase.alert;
    _logger.i('PHASE 1 (ALERT): Broadcasting distress signal and access code.');
    // Simulated SMS broadcast logic:
    // Generate one-time access code: e.g., "RESCUE-492"
    // Send SMS: "Emergency! [Name] needs help at [GPS]. Reply 'COMING' if you can help. Track location with code RESCUE-492 on the app."
  }

  Future<void> _phase2Coordinate(String sender, String text) async {
    if (_currentPhase != RescuePhase.alert && _currentPhase != RescuePhase.coordinate) return;
    
    _currentPhase = RescuePhase.coordinate;
    
    // Simulate NLP intent parsing for "I'm coming"
    if (text.toLowerCase().contains('coming') || text.toLowerCase().contains('on my way')) {
      if (!_activeRescuers.contains(sender)) {
        _activeRescuers.add(sender);
        _logger.i('PHASE 2 (COORDINATE): Rescuer $sender acknowledged SOS.');
        
        // Auto-reply to rescuer
        _logger.i('Sending to $sender: "Received. You are marked as active rescuer. Sending live updates."');
        
        // Start live guidance if this is the first rescuer
        if (_activeRescuers.length == 1) {
          _startPhase3Guidance();
        }
      }
    }
  }

  void _startPhase3Guidance() {
    _currentPhase = RescuePhase.guide;
    _logger.i('PHASE 3 (GUIDE): Starting periodic live location SMS to rescuers.');
    
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _logger.i('Pinging GPS location to ${_activeRescuers.length} active rescuers.');
      // EmergencyService.getLocation() -> send SMS to activeRescuers
    });
  }

  Future<void> _phase4Beacon() async {
    _currentPhase = RescuePhase.beacon;
    _logger.w('PHASE 4 (BEACON): User unresponsive. Activating beacon mode.');
    // Increase frequency of pings
    // Activate screen flashing
    // Play loud AudioService siren locally to guide nearby physical rescuers
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _logger.w('CRITICAL PING: Broadcasting beacon location to rescuers!');
    });
  }

  Future<void> _phase5Handoff() async {
    _currentPhase = RescuePhase.handoff;
    _logger.i('PHASE 5 (HANDOFF): Rescuer arrived. Securing scene.');
    
    _guidanceTimer?.cancel();
    _activeRescuers.clear();
    
    // Auto-SMS to all other contacts
    _logger.i('Broadcasting: "Safe. Rescue team has arrived. Handoff complete."');
    _currentPhase = RescuePhase.standby;
  }
}
