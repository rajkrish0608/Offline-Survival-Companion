import 'dart:async';
import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:logger/logger.dart';

enum SyncItemPriority {
  tier1Emergency, // SOS, Life-critical location
  tier2Health,    // Medical data, First aid updates
  tier3Comms,     // Standard Check-ins
  tier4Vault,     // Scanned documents, identities
  tier5Settings   // App configs
}

class SyncItem {
  final String id;
  final SyncItemPriority priority;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  SyncItem({
    required this.id,
    required this.priority,
    required this.payload,
  }) : createdAt = DateTime.now();
  
  // Custom comparator for Priority Queue logic
  int compareTo(SyncItem other) {
    if (priority.index != other.priority.index) {
      return priority.index.compareTo(other.priority.index);
    }
    return createdAt.compareTo(other.createdAt);
  }
}

class SyncIntelligenceAgent extends AgentBase {
  final Logger _logger = Logger();
  final List<SyncItem> _syncQueue = [];
  bool _isSyncing = false;

  @override
  String get agentName => 'Intelligent Sync Agent';

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    final String action = params['action'] ?? '';

    try {
      if (action == 'queue_item') {
        final item = SyncItem(
          id: params['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          priority: _parsePriority(params['priority'] as String?),
          payload: params['payload'] as Map<String, dynamic>? ?? {},
        );
        
        _syncQueue.add(item);
        _syncQueue.sort((a, b) => a.compareTo(b)); // Keep sorted by priority
        
        _logger.i('Agent 8: Queued item ${item.id} with priority ${item.priority.name}');
        
        return AgentResult.success(message: 'Item queued successfully.');

      } else if (action == 'flush_sync') {
        final bool hasConnection = params['has_connection'] as bool? ?? false;
        
        if (!hasConnection) {
          updateStatus(AgentStatus.idle);
          return AgentResult.fail(message: 'Cannot flush. No connection.');
        }

        if (_isSyncing) {
          return AgentResult.success(message: 'Sync already in progress.');
        }

        final result = await _flushQueue();
        return result;

      } else if (action == 'get_queue_status') {
        return AgentResult.success(
          message: 'Queue status retrieved.',
          data: {
            'pending_count': _syncQueue.length,
            'top_priority': _syncQueue.isNotEmpty ? _syncQueue.first.priority.name : 'None'
          }
        );
      } else {
        updateStatus(AgentStatus.error);
        return AgentResult.fail(message: 'Unknown Sync action.');
      }
    } catch (e) {
      _logger.e('Agent 8 failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Sync Agent error: $e');
    }
  }

  SyncItemPriority _parsePriority(String? p) {
    switch (p?.toLowerCase()) {
      case 'emergency': return SyncItemPriority.tier1Emergency;
      case 'health': return SyncItemPriority.tier2Health;
      case 'comms': return SyncItemPriority.tier3Comms;
      case 'vault': return SyncItemPriority.tier4Vault;
      case 'settings': return SyncItemPriority.tier5Settings;
      default: return SyncItemPriority.tier3Comms;
    }
  }

  Future<AgentResult> _flushQueue() async {
    _isSyncing = true;
    _logger.i('Agent 8: Starting Sync Flush of ${_syncQueue.length} items...');

    int syncedCount = 0;
    
    // Process items in order of priority
    while (_syncQueue.isNotEmpty) {
      final currentItem = _syncQueue.first;
      
      try {
        _logger.i('Agent 8 Syncing [${currentItem.priority.name}] data: ${currentItem.id}');
        // Simulate network transmit
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Remove from queue upon success
        _syncQueue.removeAt(0);
        syncedCount++;
      } catch (e) {
        _logger.e('Agent 8 Error syncing item ${currentItem.id}. Aborting flush.');
        break; // Stop syncing on network failure, retain rest of queue
      }
    }

    _isSyncing = false;
    updateStatus(AgentStatus.idle);

    if (_syncQueue.isEmpty) {
      return AgentResult.success(message: 'All queues synced successfully ($syncedCount items).');
    } else {
      return AgentResult.success(message: 'Partial flush complete. $syncedCount synced, ${_syncQueue.length} remaining.');
    }
  }
}
