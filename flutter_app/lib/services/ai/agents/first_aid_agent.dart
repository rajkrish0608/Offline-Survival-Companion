import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:logger/logger.dart';

// Offline primitive diagnostic tree
final _medicalDb = {
  'not breathing': {
    'diagnosis': 'Cardiac Arrest / Respiratory Failure',
    'steps': [
      'Call for emergency medical help immediately.',
      'Check airway - tilt head back gently.',
      'Begin CPR: Push hard and fast in the center of the chest (100-120 beats per minute).',
      'If trained, give 2 rescue breaths after every 30 compressions.',
      'Continue until help arrives or the person breathing normally.'
    ],
    'severity': 'Critical'
  },
  'bleeding heavily': {
    'diagnosis': 'Severe Hemorrhage',
    'steps': [
      'Apply firm, direct pressure to the wound with a clean cloth.',
      'Elevate the injured area above the heart if possible.',
      'If bleeding continues and soaks through, add another cloth. Do NOT remove the first one.',
      'If bleeding is life-threatening and on a limb, apply a tourniquet 2-3 inches above the wound. Note the time.'
    ],
    'severity': 'Critical'
  },
  'burn': {
    'diagnosis': 'Thermal Burn',
    'steps': [
      'Cool the burn immediately with cool (not ice cold) running water for 10-15 minutes.',
      'Remove constricting items (rings, belts) near the burn area.',
      'Do absolutely NOT apply butter, oil, or ice.',
      'Cover with a sterile, non-fluffy dressing or clear plastic wrap.',
      'Seek medical help if the burn is larger than the palm of your hand, on the face, or deep.'
    ],
    'severity': 'Moderate'
  },
  'snake': {
    'diagnosis': 'Snake Bite',
    'steps': [
      'Keep the person calm and completely still to slow the spread of venom.',
      'Remove jewelry or tight clothing before swelling starts.',
      'Keep the bitten area at or BELOW heart level.',
      'Do NOT cut the wound, attempt to suck out the venom, or apply a tourniquet.',
      'Get emergency medical help immediately. Try to remember the snake\'s color and shape.'
    ],
    'severity': 'Critical'
  },
  'choking': {
    'diagnosis': 'Airway Obstruction (Choking)',
    'steps': [
      'If they can cough loudly, encourage them to keep coughing. Do nothing else.',
      'If they cannot breathe, speak, or cough loudly, give 5 back blows between the shoulder blades.',
      'Give 5 abdominal thrusts (Heimlich maneuver).',
      'Alternate until the blockage is dislodged.'
    ],
    'severity': 'Critical'
  }
};

class FirstAidAgent extends AgentBase {
  final Logger _logger = Logger();

  @override
  String get agentName => 'First Aid Diagnosis Agent';

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final symptoms = params['symptoms'] as String?;
    
    if (symptoms == null || symptoms.trim().isEmpty) {
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'No symptoms provided for diagnosis.');
    }

    _logger.i('Agent 3 analyzing symptoms: "$symptoms"');
    
    // Offline rule-based NLP matching
    final diagnosis = _diagnose(symptoms.toLowerCase());

    if (diagnosis != null) {
      updateStatus(AgentStatus.success);
      return AgentResult.success(
        message: 'Matches found for: ${diagnosis['diagnosis']}',
        data: diagnosis,
      );
    } else {
      updateStatus(AgentStatus.success); // Success because processing finished, but no specific match
      return AgentResult.success(
        message: 'No exact matches found.',
        data: {
          'diagnosis': 'Unknown / General Trauma',
          'steps': [
            'Ensure the scene is safe.',
            'Keep the person calm and comfortable.',
            'Do not move them unless they are in immediate danger.',
            'Seek professional medical help if in doubt.'
          ],
          'severity': 'Unknown'
        }
      );
    }
  }

  Map<String, dynamic>? _diagnose(String input) {
    for (var key in _medicalDb.keys) {
      if (input.contains(key)) {
        return _medicalDb[key];
      }
    }
    return null;
  }
}
