import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:logger/logger.dart';

class AutoCallerAgent extends AgentBase {
  final FlutterTts _tts = FlutterTts();
  final LocalStorageService _storageService;
  final Logger _logger = Logger();

  @override
  String get agentName => 'Auto Caller Agent';

  AutoCallerAgent({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final userId = params['userId'] as String;
    final severity = params['severity'] as String? ?? 'critical';
    
    try {
      final contacts = await _storageService.getEmergencyContacts(userId);
      if (contacts.isEmpty) {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'No emergency contacts found.');
      }

      final user = await _storageService.getUser(userId);
      final userName = user?['name'] ?? 'User';
      
      final script = _generateCallScript(userName, severity, params['location']);
      
      _logger.i('Auto Caller Agent: Initiating emergency calls for $userId');

      for (var contact in contacts) {
        final phone = contact['phone'] as String;
        final name = contact['name'] as String? ?? 'Contact';
        
        _logger.i('Attempting to call $name at $phone');
        
        // In a real device, this uses direct caller. 
        // fallback to url_launcher if needed.
        bool? res = await FlutterPhoneDirectCaller.callNumber(phone);
        
        if (res == true) {
          _logger.i('Call initiated to $phone');
          // Wait a bit for connection before speaking
          await Future.delayed(const Duration(seconds: 3));
          await _tts.setLanguage("en-US");
          await _tts.setPitch(1.0);
          await _tts.speak(script);
          
          updateStatus(AgentStatus.success);
          return AgentResult.success(message: 'Call initiated to $name', data: {'contact': name, 'phone': phone});
        } else {
          _logger.w('Direct call failed for $phone, trying next...');
        }
      }

      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Failed to initiate any calls.');
    } catch (e) {
      _logger.e('AutoCallerAgent Error: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Error during execution: $e');
    }
  }

  String _generateCallScript(String userName, String severity, dynamic location) {
    String locationStr = '';
    if (location != null && location is Map) {
      locationStr = 'at Latitude ${location['lat']}, Longitude ${location['lng']}';
    }
    
    return "This is an automated emergency alert from the Offline Survival Companion. "
           "User $userName is in a $severity situation $locationStr. "
           "Please check the SOS message sent to your phone and take immediate action. "
           "I repeat, this is an emergency alert for $userName.";
  }
}
