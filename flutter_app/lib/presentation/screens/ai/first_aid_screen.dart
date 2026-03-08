import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Widget> _chatItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addSystemMessage("Agent 3: First Aid offline system running. Describe the symptoms or injury (e.g., 'burned my hand' or 'bleeding heavily').");
  }

  void _addSystemMessage(String text) {
    setState(() {
      _chatItems.insert(0, _buildChatBubble(text, false));
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      _chatItems.insert(0, _buildChatBubble(text, true));
    });
  }

  Future<void> _analyzeSymptoms() async {
    if (_controller.text.trim().isEmpty) return;

    final symptoms = _controller.text.trim();
    _controller.clear();

    _addUserMessage(symptoms);

    setState(() {
      _isLoading = true;
    });

    final result = await AgentOrchestrator.instance.dispatch(
      AgentType.firstAid,
      {'symptoms': symptoms},
    );

    setState(() {
      _isLoading = false;
      if (result.status == ResultStatus.success && result.data != null) {
        // Build interactive step-by-step UI from agent data
        _chatItems.insert(0, _buildDiagnosisCard(result.data!));
      } else {
        _addSystemMessage(result.message);
      }
    });
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.accentRed : AppTheme.surfaceDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.borderDark),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : AppTheme.textLight,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(Map<String, dynamic> data) {
    final diagnosis = data['diagnosis'] as String;
    final severity = data['severity'] as String;
    final steps = List<String>.from(data['steps'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRed.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services, color: AppTheme.accentRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diagnosis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severity == 'Critical' ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(severity, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const Divider(color: AppTheme.borderDark, height: 24),
          const Text('Action Steps:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.accentBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(step, style: const TextStyle(color: AppTheme.textLight, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Aid Agent'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Start from bottom
              padding: const EdgeInsets.all(16),
              itemCount: _chatItems.length,
              itemBuilder: (context, index) {
                return _chatItems[index];
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.accentRed),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter symptoms (e.g., severe bleeding)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _analyzeSymptoms(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.accentRed,
              child: IconButton(
                icon: const Icon(Icons.healing, color: Colors.white),
                onPressed: _analyzeSymptoms,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
