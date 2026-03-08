import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/ai/agents/auto_caller_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/emergency_response_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/voice_command_agent.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';

enum AgentType {
  emergencyResponse,
  survivalAdvisor,
  firstAid,
  situationAwareness,
  vaultIntelligence,
  smartComms,
  mapIntelligence,
  sync,
  autoCaller,
  voiceCommand,
}

class AgentOrchestrator {
  static final AgentOrchestrator instance = AgentOrchestrator._();
  AgentOrchestrator._();

  final Map<AgentType, AgentBase> _agents = {};
  bool _initialized = false;

  Future<void> initialize({LocalStorageService? storageService}) async {
    if (_initialized) return;

    final storage = storageService ?? LocalStorageService();
    
    // Register agents
    _agents[AgentType.autoCaller] = AutoCallerAgent(storageService: storage);
    _agents[AgentType.emergencyResponse] = EmergencyResponseAgent(storageService: storage);
    _agents[AgentType.voiceCommand] = VoiceCommandAgent();
    
    _initialized = true;
  }

  Future<AgentResult> dispatch(AgentType type, Map<String, dynamic> params) async {
    if (!_initialized) {
      return AgentResult.fail(message: 'AgentOrchestrator not initialized');
    }

    final agent = _agents[type];
    if (agent == null) {
      return AgentResult.fail(message: 'Agent $type not implemented yet');
    }

    return await agent.execute(params);
  }

  AgentBase? getAgent(AgentType type) => _agents[type];
}
