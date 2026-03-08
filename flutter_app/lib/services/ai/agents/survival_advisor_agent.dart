import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:logger/logger.dart';

class SurvivalAdvisorAgent extends AgentBase {
  final Logger _logger = Logger();
  late final GenerativeModel _model;
  
  List<Map<String, dynamic>> _knowledgeBase = [];
  bool _initialized = false;

  @override
  String get agentName => 'Survival Advisor Agent';

  Future<void> initialize(String apiKey) async {
    if (_initialized) return;
    
    // In a real offline-only scenario, you would use TFLite or MediaPipe LLM Inference API here.
    // For this implementation, we use google_generative_ai with the 'gemini-1.5-flash' model
    // which simulates the "smart" capability. When Gemini Nano is fully supported in 
    // google_generative_ai Dart SDK, this exact same interface is used.
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    try {
      final String jsonStr = await rootBundle.loadString('assets/ai/survival_knowledge_base.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _knowledgeBase = jsonList.map((e) => e as Map<String, dynamic>).toList();
      _logger.i('Loaded ${_knowledgeBase.length} knowledge items into Agent 2 memory.');
      _initialized = true;
    } catch (e) {
      _logger.e('Failed to load survival knowledge base: $e');
    }
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    
    if (!_initialized) {
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Agent not initialized. Ensure API key is set.');
    }

    final query = params['query'] as String?;
    if (query == null || query.isEmpty) {
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'No query provided to Survival Advisor.');
    }

    _logger.i('Agent 2 received query: "$query"');

    try {
      // 1. Retrieval (Offline RAG)
      // Find the most relevant piece of knowledge based on keyword matching
      String context = _retrieveContext(query);

      // 2. Generation
      // Construct prompt injecting the retrieved context
      final prompt = '''
You are the Offline Survival Companion AI. Answer the user's survival question based STRICTLY on the context provided below.
If the context does not contain the answer, say "I don't have offline data for that specific situation, please refer to the main guide."
Do not give dangerous medical advice. Be concise, calm, and clear.

CONTEXT:
$context

USER QUESTION:
$query

ANSWER:
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      updateStatus(AgentStatus.success);
      return AgentResult.success(
        message: 'Response generated successfully',
        data: {'response': response.text?.trim() ?? 'I could not generate a response.'},
      );
    } catch (e) {
      _logger.e('Error generating survival advice: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Failed to generate survival advice: $e');
    }
  }

  String _retrieveContext(String query) {
    final lowerQuery = query.toLowerCase();
    final words = lowerQuery.split(' ');
    
    // Simple relevance scoring: counting keyword matches in the 'topic' and 'content'
    int bestScore = -1;
    Map<String, dynamic>? bestMatch;

    for (var item in _knowledgeBase) {
      int score = 0;
      final topic = (item['topic'] as String).toLowerCase();
      final content = (item['content'] as String).toLowerCase();
      
      for (var word in words) {
        if (word.length < 4) continue; // Skip common words
        if (topic.contains(word)) score += 3;
        if (content.contains(word)) score += 1;
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestScore > 0 && bestMatch != null) {
      return "${bestMatch['topic']}: ${bestMatch['content']}";
    }
    
    return "No specific offline context found. Rely on general safety knowledge.";
  }
}
