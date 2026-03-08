import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/ai/agents/auto_caller_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/emergency_response_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/voice_command_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/survival_advisor_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/first_aid_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/scheduler_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/situation_awareness_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/rescue_coordinator_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/mental_health_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/vault_intelligence_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/weather_prediction_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/supply_tracker_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/identity_obfuscation_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/map_intelligence_agent.dart';
import 'package:offline_survival_companion/services/ai/agents/sync_intelligence_agent.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  scheduler,
  rescueCoordinator,
  mentalHealth,
  weatherPrediction,
  supplyTracker,
  identityObfuscation,
}

class AgentOrchestrator {
  static final AgentOrchestrator instance = AgentOrchestrator._();
  AgentOrchestrator._();

  final Map<AgentType, AgentBase> _agents = {};
  bool _initialized = false;

  Future<void> initialize({LocalStorageService? storageService}) async {
    if (_initialized) return;

    final storage = storageService ?? LocalStorageService();
    
    // Grab API key for agents that need it (Agent 2)
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    
    // Register agents
    _agents[AgentType.autoCaller] = AutoCallerAgent(storageService: storage);
    _agents[AgentType.emergencyResponse] = EmergencyResponseAgent(storageService: storage);
    _agents[AgentType.voiceCommand] = VoiceCommandAgent();
    _agents[AgentType.firstAid] = FirstAidAgent();
    _agents[AgentType.rescueCoordinator] = RescueCoordinatorAgent();
    _agents[AgentType.mentalHealth] = MentalHealthAgent();
    _agents[AgentType.vaultIntelligence] = VaultIntelligenceAgent();
    _agents[AgentType.supplyTracker] = SupplyTrackerAgent(storageService: storage);
    _agents[AgentType.identityObfuscation] = IdentityObfuscationAgent();
    _agents[AgentType.mapIntelligence] = MapIntelligenceAgent();
    _agents[AgentType.sync] = SyncIntelligenceAgent();
    
    final weather = WeatherPredictionAgent();
    _agents[AgentType.weatherPrediction] = weather;
    weather.startMonitoring(); // Auto-start background weather analysis
    
    final awareness = SituationAwarenessAgent();
    _agents[AgentType.situationAwareness] = awareness;
    // Auto-start background monitoring immediately upon init
    awareness.startMonitoring();
    
    final scheduler = SchedulerAgent(storageService: storage);
    await scheduler.initialize();
    _agents[AgentType.scheduler] = scheduler;
    
    final advisor = SurvivalAdvisorAgent();
    await advisor.initialize(geminiKey);
    _agents[AgentType.survivalAdvisor] = advisor;
    
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
