import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';

class VoiceCommandOverlay extends StatefulWidget {
  const VoiceCommandOverlay({super.key});

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String _statusText = "Tap to speak...";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    final appState = context.read<AppBloc>().state;
    final userId = (appState is AppReady) ? appState.userId : 'local_user';

    setState(() {
      _isListening = !_isListening;
      _statusText = _isListening ? "Listening for commands..." : "Tap to speak...";
    });

    if (_isListening) {
      final result = await AgentOrchestrator.instance.dispatch(
        AgentType.voiceCommand, 
        {'action': 'start_listening', 'userId': userId}
      );
      
      if (result.status == ResultStatus.fail) {
        setState(() {
          _isListening = false;
          _statusText = result.message;
        });
      }
    } else {
      await AgentOrchestrator.instance.dispatch(
        AgentType.voiceCommand, 
        {'action': 'stop_listening'}
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Agent 10: Voice Command',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _isListening ? AppTheme.accentBlue : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening 
                        ? AppTheme.accentBlue.withOpacity(0.2 + (_pulseController.value * 0.3))
                        : AppTheme.surfaceDark,
                    border: Border.all(
                      color: _isListening ? AppTheme.accentBlue : AppTheme.borderDark,
                      width: 2,
                    ),
                    boxShadow: _isListening ? [
                      BoxShadow(
                        color: AppTheme.accentBlue.withOpacity(0.5),
                        blurRadius: 20 * _pulseController.value,
                        spreadRadius: 5 * _pulseController.value,
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 48,
                      color: _isListening ? AppTheme.accentBlue : AppTheme.textLight,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Try saying:\n"Send SOS" • "Turn on flashlight" • "Where am I?"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
