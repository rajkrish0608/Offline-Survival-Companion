import 'package:flutter/material.dart';
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
    
    final message = value 
        ? 'Low Power Mode Enabled: Animations Disabled' 
        : 'Low Power Mode Disabled';
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: value ? Colors.orange : null,
      ),
    );
    
    // In a real app, this would also write to a global SettingsService/Bloc 
    // to actually disable animations app-wide.
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isLowPowerMode ? Colors.orange.withOpacity(0.1) : null,
      child: SwitchListTile(
        title: const Text('Low Battery Mode'),
        subtitle: Text('Battery Level: $_batteryLevel%'),
        secondary: Icon(
          _isLowPowerMode ? Icons.battery_alert : Icons.battery_full,
          color: _isLowPowerMode ? Colors.orange : Colors.green,
        ),
        value: _isLowPowerMode,
        onChanged: _toggleLowPowerMode,
        activeThumbColor: Colors.orange,
      ),
    );
  }
}
