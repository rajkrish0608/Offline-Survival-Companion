import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:logger/logger.dart';

class IdentityObfuscationAgent extends AgentBase {
  final Logger _logger = Logger();
  bool _isFakeModeActive = false;

  @override
  String get agentName => 'Identity Obfuscation Agent';

  bool get isFakeModeActive => _isFakeModeActive;

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final String action = params['action'] ?? '';

    try {
      if (action == 'verify_pin') {
        final String pin = params['pin'] as String;
        final String realPin = params['real_pin'] as String; // Passed from local storage
        final String panicPin = params['panic_pin'] as String;

        if (pin == panicPin) {
          await _triggerPanicMode();
          return AgentResult.success(
            message: 'Panic PIN accepted. Entering Fake App Mode.',
            data: {'route': '/fake-dashboard'},
          );
        } else if (pin == realPin) {
          _isFakeModeActive = false;
          return AgentResult.success(
            message: 'Real PIN accepted. Normal Mode.',
            data: {'route': '/home'},
          );
        } else {
          return AgentResult.fail(message: 'Incorrect PIN');
        }
      } else if (action == 'deactivate_panic_mode') {
        _isFakeModeActive = false;
        _logger.w('Agent 6: Panic Mode DEACTIVATED manually.');
        return AgentResult.success(message: 'Restored normal app state.');
      } else {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'Unknown Obfuscation action.');
      }
    } catch (e) {
      _logger.e('Agent 6 failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Identity obfuscation error: $e');
    }
  }

  Future<void> _triggerPanicMode() async {
    _isFakeModeActive = true;
    _logger.w('CRITICAL: Panic PIN entered! Agent 6 initiating Obfuscation Protocol.');
    
    // 1. Send silent SOS via Agent 1 (Emergency Response Agent)
    _logger.w('Agent 6: Dispatching Silent SOS to Agent 1');
    AgentOrchestrator.instance.dispatch(
      AgentType.emergencyResponse, 
      {'action': 'trigger_sos', 'is_silent': true}
    );

    // 2. Lock Sensitive Vault Data (Conceptual - UI will hide Vault)
    _logger.w('Agent 6: Locking Vault and hiding tracks.');

    // 3. Fake Dashboard generated in UI
    updateStatus(AgentStatus.idle);
  }
}
