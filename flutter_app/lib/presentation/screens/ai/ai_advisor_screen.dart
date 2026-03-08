import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class AIAdvisorScreen extends StatefulWidget {
  const AIAdvisorScreen({super.key});

  @override
  State<AIAdvisorScreen> createState() => _AIAdvisorScreenState();
}

class _AIAdvisorScreenState extends State<AIAdvisorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: "Agent 2: Survival Advisor online. I have loaded your local offline survival database. How can I help you survive today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final query = _controller.text.trim();
    _controller.clear();

    setState(() {
      _messages.insert(0, ChatMessage(text: query, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    final result = await AgentOrchestrator.instance.dispatch(
      AgentType.survivalAdvisor,
      {'query': query},
    );

    setState(() {
      _isLoading = false;
      if (result.status == ResultStatus.success) {
        _messages.insert(
          0,
          ChatMessage(
            text: result.data?['response'] ?? "I could not process that request.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        _messages.insert(
          0,
          ChatMessage(
            text: "Error: ${result.message}",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survival Advisor'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Start from bottom
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.accentBlue),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.accentBlue : AppTheme.surfaceDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 16),
          ),
          border: message.isUser ? null : Border.all(color: AppTheme.borderDark),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : AppTheme.textLight,
            fontSize: 16,
          ),
        ),
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
                  hintText: 'Ask a survival question...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.accentBlue,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
