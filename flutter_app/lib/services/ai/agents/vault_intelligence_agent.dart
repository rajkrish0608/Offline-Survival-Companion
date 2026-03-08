import 'dart:io';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

class VaultIntelligenceAgent extends AgentBase {
  final Logger _logger = Logger();
  late final TextRecognizer _textRecognizer;

  @override
  String get agentName => 'Vault Intelligence Agent';

  VaultIntelligenceAgent() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final String action = params['action'] ?? '';

    try {
      if (action == 'process_document') {
        final filePath = params['file_path'] as String?;
        if (filePath == null || !File(filePath).existsSync()) {
          updateStatus(AgentStatus.error);
          return AgentResult.fail(message: 'Valid file_path required for OCR.');
        }

        _logger.i('Agent 5 OCR processing file: $filePath');
        final inputImage = InputImage.fromFilePath(filePath);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        
        // Auto-Categorizer
        final documentText = recognizedText.text.toLowerCase();
        final category = _autoCategorize(documentText);
        
        // Extract Expiry Date (crude regex simulation for IDs/Passports)
        final expiry = _extractExpiryDate(documentText);

        updateStatus(AgentStatus.success);
        return AgentResult.success(
          message: 'Document successfully classified.',
          data: {
            'text_snapshot': recognizedText.text.substring(0, recognizedText.text.length > 100 ? 100 : recognizedText.text.length),
            'category': category,
            'identified_expiry': expiry,
          }
        );
      } else if (action == 'semantic_search') {
        final query = params['query'] as String?;
        // Semantic Search simulation across vault DB
        _logger.i('Agent 5 Semantic Search for: $query');
        
        updateStatus(AgentStatus.success);
        return AgentResult.success(
          message: 'Semantic search complete',
          data: {'results': ['Mock Match 1', 'Mock Match 2']}
        );
      } else {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'Unknown vault intelligence action.');
      }
    } catch (e) {
      _logger.e('Agent 5 Vault Processing failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Vault intelligence error: $e');
    }
  }

  String _autoCategorize(String text) {
    if (text.contains('medical') || text.contains('health') || text.contains('doctor') || text.contains('rx')) {
      return 'Medical';
    } else if (text.contains('insurance') || text.contains('policy') || text.contains('liability')) {
      return 'Insurance';
    } else if (text.contains('passport') || text.contains('id') || text.contains('license') || text.contains('identity')) {
      return 'Identity';
    } else if (text.contains('bank') || text.contains('account') || text.contains('tax')) {
      return 'Financial';
    }
    return 'General';
  }

  String? _extractExpiryDate(String text) {
    // Basic regex for DD/MM/YYYY or YYYY-MM-DD
    final regex = RegExp(r'(\d{2}/\d{2}/\d{4})|(\d{4}-\d{2}-\d{2})');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
