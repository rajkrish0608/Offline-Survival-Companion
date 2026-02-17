import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

class BatteryService {
  final Battery _battery = Battery();

  // Get current battery level
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      debugPrint('Error getting battery level: $e');
      return 100; // Default to full if unknown to avoid panic mode
    }
  }

  // Get current battery state
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.onBatteryStateChanged.first;
    } catch (e) {
      return BatteryState.unknown;
    }
  }

  // Stream for battery state changes
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}
