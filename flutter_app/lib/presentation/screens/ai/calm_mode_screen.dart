import 'package:flutter/material.dart';
import 'dart:async';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/ai/core/agent_orchestrator.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';

class CalmModeScreen extends StatefulWidget {
  const CalmModeScreen({super.key});

  @override
  State<CalmModeScreen> createState() => _CalmModeScreenState();
}

class _CalmModeScreenState extends State<CalmModeScreen> with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  List<Map<String, dynamic>> _breathingSteps = [];
  Timer? _stepTimer;
  int _timeRemaining = 0;
  bool _isActive = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadBreathingExercise();
  }

  Future<void> _loadBreathingExercise() async {
    final result = await AgentOrchestrator.instance.dispatch(
      AgentType.mentalHealth,
      {'action': 'get_breathing_exercise'},
    );

    if (result.status == ResultStatus.success && result.data != null) {
      if (mounted) {
        setState(() {
          _breathingSteps = List<Map<String, dynamic>>.from(result.data!['steps']);
        });
      }
    }
  }

  void _toggleExercise() {
    if (_isActive) {
      _stopExercise();
    } else if (_breathingSteps.isNotEmpty) {
      _startExercise();
    }
  }

  void _startExercise() {
    setState(() {
      _isActive = true;
      _currentStepIndex = 0;
    });
    _runStep();
  }

  void _stopExercise() {
    _stepTimer?.cancel();
    _animationController.stop();
    setState(() {
      _isActive = false;
      _timeRemaining = 0;
    });
  }

  void _runStep() {
    if (!mounted || !_isActive) return;

    final step = _breathingSteps[_currentStepIndex];
    final int duration = step['duration_sec'] as int;
    final String instruction = step['instruction'] as String;

    setState(() {
      _timeRemaining = duration;
    });

    if (instruction.toLowerCase().contains('inhale')) {
      _animationController.duration = Duration(seconds: duration);
      _animationController.forward();
    } else if (instruction.toLowerCase().contains('exhale')) {
      _animationController.duration = Duration(seconds: duration);
      _animationController.reverse();
    } else {
      _animationController.stop();
    }

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _currentStepIndex = (_currentStepIndex + 1) % _breathingSteps.length;
        _runStep();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Calm Center (Agent 16)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: _breathingSteps.isEmpty
            ? const CircularProgressIndicator(color: AppTheme.accentBlue)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isActive ? _breathingSteps[_currentStepIndex]['instruction'] : 'Box Breathing (4-4-4)',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isActive ? '$_timeRemaining sec' : 'Press Start to Begin',
                    style: TextStyle(color: AppTheme.textLight.withOpacity(0.7), fontSize: 18),
                  ),
                  const SizedBox(height: 60),
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isActive ? _scaleAnimation.value : 1.0,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentBlue.withOpacity(0.2),
                            border: Border.all(color: AppTheme.accentBlue, width: 4),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.air,
                              color: AppTheme.accentBlue.withOpacity(0.8),
                              size: 50,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                  ElevatedButton(
                    onPressed: _toggleExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isActive ? AppTheme.accentRed : AppTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      _isActive ? 'STOP' : 'START',
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
