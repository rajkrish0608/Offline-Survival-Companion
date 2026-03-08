import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';

// Note: To use Porcupine wake-word offline, an access key is typically required.
// For this MVP implementation, we simulate the wake word logic and focus on
// the offline NLP command parsing using string similarity (classic offline NLP).
// If a local LLM is available, this can be swapped to zero-shot classification.

enum VoiceIntent {
  sendSOS,
  turnOnFlashlight,
  turnOffFlashlight,
  whereAmI,
  readFirstAid,
  unknown
}

class VoiceCommandAgent extends AgentBase {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Logger _logger = Logger();
  
  bool _isListening = false;
  bool _isSpeechInitialized = false;

  @override
  String get agentName => 'Voice Command Agent';

  Future<void> initialize() async {
    _logger.i('Agent 10 (Voice Command) initializing STT subsystem');
    _isSpeechInitialized = await _speechToText.initialize(
      onError: (val) => _logger.e('STT Error: $val'),
      onStatus: (val) => _logger.i('STT Status: $val'),
    );
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final action = params['action'] as String? ?? 'start_listening';
    
    if (action == 'stop_listening') {
      await _stopListening();
      updateStatus(AgentStatus.success);
      return AgentResult.success(message: 'Stopped listening');
    }

    if (!_isSpeechInitialized) {
      await initialize();
    }

    if (!_isSpeechInitialized) {
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Speech recognition not available or denied on device.');
    }

    _startListening(params['userId']);
    
    updateStatus(AgentStatus.success);
    return AgentResult.success(message: 'Voice Command Agent is actively listening');
  }

  void _startListening(String? userId) {
    if (_isListening) return;
    
    _logger.i('Agent 10 listening for commands...');
    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          _processCommand(result.recognizedWords, userId);
        }
      },
      listenFor: const Duration(seconds: 10),
      // Uses on-device speech recognition to preserve offline-first rule
      onDevice: true,
    );
    _isListening = true;
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  Future<void> _processCommand(String rawText, String? userId) async {
    _logger.i('Raw Voice Command: "$rawText"');
    
    final intent = _parseIntentOffline(rawText);
    _logger.i('Parsed offline intent: $intent');

    switch (intent) {
      case VoiceIntent.sendSOS:
        await _tts.speak('SOS command received. Activating emergency protocol.');
        if (userId != null) {
          AgentOrchestrator.instance.dispatch(
            AgentType.emergencyResponse, 
            {'userId': userId}
          );
        }
        break;
      
      case VoiceIntent.turnOnFlashlight:
        await _tts.speak('Turning on flashlight');
        // This would typically interface with an EventBus or the EmergencyService directly
        // For orchestration abstraction, we might need a HardwareAgent or direct call
        break;

      case VoiceIntent.turnOffFlashlight:
        await _tts.speak('Turning off flashlight');
        break;

      case VoiceIntent.whereAmI:
        await _tts.speak('Checking your location now.');
        // Hook into MapIntelAgent
        break;

      case VoiceIntent.readFirstAid:
        await _tts.speak('Opening first aid assistant.');
        break;

      case VoiceIntent.unknown:
        await _tts.speak('Command not recognized. Please say help or SOS.');
        break;
    }
  }

  // Uses lightweight offline NLP (String Similarity) since running an LLM for
  // every single spoken word continuously drains battery. 
  // We match spoken text against known trigger phrases.
  VoiceIntent _parseIntentOffline(String text) {
    final t = text.toLowerCase();
    
    final sosTriggers = ["help me", "send sos", "emergency", "call for help", "i need help"];
    final lightOnTriggers = ["turn on flashlight", "lights on", "it's dark", "flashlight on"];
    final lightOffTriggers = ["turn off flashlight", "lights off", "flashlight off"];
    final locTriggers = ["where am i", "what is my location", "get my location"];
    final aidTriggers = ["first aid", "i am hurt", "how to treat", "medical help"];

    if (_matches(t, sosTriggers)) return VoiceIntent.sendSOS;
    if (_matches(t, lightOnTriggers)) return VoiceIntent.turnOnFlashlight;
    if (_matches(t, lightOffTriggers)) return VoiceIntent.turnOffFlashlight;
    if (_matches(t, locTriggers)) return VoiceIntent.whereAmI;
    if (_matches(t, aidTriggers)) return VoiceIntent.readFirstAid;

    return VoiceIntent.unknown;
  }

  bool _matches(String utterance, List<String> targets) {
    // Dice's Coefficient string similarity -> score 0.0 to 1.0
    for (var target in targets) {
      if (utterance.similarityTo(target) > 0.6 || utterance.contains(target)) {
        return true;
      }
    }
    return false;
  }
}
