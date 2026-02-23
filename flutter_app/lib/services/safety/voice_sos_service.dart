import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:logger/logger.dart';

import 'package:flutter/foundation.dart';

class VoiceSosService extends ChangeNotifier {
  final EmergencyService _emergencyService;
  final SpeechToText _speech = SpeechToText();
  final Logger _logger = Logger();

  bool _isListening = false;
  bool _isEnabled = false;
  String _triggerPhrase = "help help help";
  String? _userId;

  VoiceSosService(this._emergencyService);

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;

  Future<void> initialize({required String userId}) async {
    _userId = userId;
    bool available = await _speech.initialize(
      onStatus: (status) => _logger.i('Speech status: $status'),
      onError: (error) => _logger.e('Speech error: $error'),
    );
    
    if (available) {
      _logger.i('Voice SOS Service initialized');
    } else {
      _logger.w('Speech recognition not available');
    }
  }

  void setEnabled(bool value) {
    _isEnabled = value;
    notifyListeners();
    if (_isEnabled) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() async {
    if (!_isEnabled || _isListening) return;

    _isListening = true;
    notifyListeners();
    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        _logger.d('Heard: $words');
        if (words.contains(_triggerPhrase)) {
          _triggerSOS();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.confirmation,
    );

    // Re-start listening after it stops naturally
    Timer(const Duration(seconds: 31), () {
      if (_isEnabled) {
        _isListening = false;
        _startListening();
      }
    });
  }

  void _stopListening() {
    _isListening = false;
    _speech.stop();
  }

  void _triggerSOS() {
    if (_userId != null) {
      _logger.w('VOICE TRIGGER DETECTED! Activating SOS.');
      _emergencyService.activateSOS(
        userId: _userId!,
        customMessage: 'Voice Activated SOS: Trigger phrase detected.',
      );
    }
  }

  void dispose() {
    _isEnabled = false;
    _speech.cancel();
  }
}
