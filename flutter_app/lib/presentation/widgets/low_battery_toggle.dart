import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/services/power/battery_service.dart';

class LowBatteryToggle extends StatefulWidget {
  const LowBatteryToggle({super.key});

  @override
  State<LowBatteryToggle> createState() => _LowBatteryToggleState();
}

class _LowBatteryToggleState extends State<LowBatteryToggle> {
  final BatteryService _batteryService = BatteryService();
  bool _isLowPowerMode = false;
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    final level = await _batteryService.getBatteryLevel();
    if (mounted) {
      setState(() {
        _batteryLevel = level;
        // Auto-enable if below 20%
        if (level <= 20) {
          _isLowPowerMode = true;
        }
      });
    }
  }

  void _toggleLowPowerMode(bool value) {
    setState(() => _isLowPowerMode = value);
    
    // Dispatch event to Bloc
    context.read<AppBloc>().add(SurvivalModeToggled(value));
    
    final message = value 
        ? 'Survival Mode Enabled: High Contrast Active' 
        : 'Survival Mode Disabled';
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: value ? Colors.black : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isLowPowerMode ? Colors.yellow.withOpacity(0.1) : null,
      child: SwitchListTile(
        title: const Text('Survival Mode'),
        subtitle: Text('Battery Level: $_batteryLevel%'),
        secondary: Icon(
          _isLowPowerMode ? Icons.bolt : Icons.battery_full,
          color: _isLowPowerMode ? Colors.yellow : Colors.green,
        ),
        value: _isLowPowerMode,
        onChanged: _toggleLowPowerMode,
        activeThumbColor: Colors.yellow,
      ),
    );
  }
}
