import 'dart:convert';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:logger/logger.dart';

class SupplyTrackerAgent extends AgentBase {
  final Logger _logger = Logger();
  final LocalStorageService _storageService;

  @override
  String get agentName => 'Supply & Resource Tracker Agent';

  SupplyTrackerAgent({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final String action = params['action'] ?? '';

    try {
      if (action == 'add_supply') {
        final name = params['name'] as String;
        final details = params['details'] as Map<String, dynamic>; // e.g. {'quantity': 10, 'unit': 'liters', 'daily_burn': 2}
        await _addSupply(name, details);
        return AgentResult.success(message: 'Supply added/updated: $name');
      } else if (action == 'consume_supply') {
        final name = params['name'] as String;
        final amount = params['amount'] as num;
        await _consumeSupply(name, amount);
        return AgentResult.success(message: 'Consumed $amount of $name');
      } else if (action == 'audit_supplies') {
        final audit = await _auditSupplies();
        return AgentResult.success(
          message: 'Inventory audit complete.',
          data: audit,
        );
      } else {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'Unknown Supply Tracker action.');
      }
    } catch (e) {
      _logger.e('Agent 15 failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Supply tracking error: $e');
    }
  }

  Future<Map<String, dynamic>> _getInventory() async {
    final data = await _storageService.read('inventory_data');
    if (data == null) return {};
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> _saveInventory(Map<String, dynamic> inventory) async {
    await _storageService.save('inventory_data', jsonEncode(inventory));
  }

  Future<void> _addSupply(String name, Map<String, dynamic> details) async {
    final inventory = await _getInventory();
    
    if (inventory.containsKey(name)) {
      // Add quantity
      inventory[name]['quantity'] = (inventory[name]['quantity'] as num) + (details['quantity'] as num);
    } else {
      inventory[name] = details;
    }
    
    await _saveInventory(inventory);
    _logger.i('Agent 15: Inventory updated for $name');
  }

  Future<void> _consumeSupply(String name, num amount) async {
    final inventory = await _getInventory();
    
    if (inventory.containsKey(name)) {
      num current = inventory[name]['quantity'] as num;
      num after = current - amount;
      if (after < 0) after = 0;
      
      inventory[name]['quantity'] = after;
      await _saveInventory(inventory);
      _logger.i('Agent 15: Consumed $amount of $name. Remaining: $after');
      
      // Check threshold
      if (after <= (inventory[name]['critical_threshold'] ?? 1)) {
        _logger.w('Agent 15: CRITICAL ALERT. $name is running low!');
      }
    }
  }

  Future<Map<String, dynamic>> _auditSupplies() async {
    final inventory = await _getInventory();
    final Map<String, dynamic> audit = {
      'critical_items': [],
      'safe_items': [],
      'days_of_water_left': 0,
      'days_of_food_left': 0,
    };

    inventory.forEach((name, details) {
      num qty = details['quantity'] as num;
      num burn = details['daily_burn'] ?? 1;
      num threshold = details['critical_threshold'] ?? 1;
      
      num daysLeft = qty / (burn > 0 ? burn : 1);
      
      if (qty <= threshold || daysLeft <= 2) {
        audit['critical_items'].add({name: daysLeft});
      } else {
        audit['safe_items'].add({name: daysLeft});
      }
      
      if (name.toLowerCase() == 'water') audit['days_of_water_left'] = daysLeft;
      if (name.toLowerCase() == 'food') audit['days_of_food_left'] = daysLeft;
    });

    _logger.i('Agent 15 Audit: ${audit['critical_items'].length} critical items.');
    return audit;
  }
}
