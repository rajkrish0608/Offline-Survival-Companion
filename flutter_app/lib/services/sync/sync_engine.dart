import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:math';

class SyncEngine {
  final LocalStorageService _storageService;
  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _retryTimer;

  int _retryCount = 0;
  final int _maxRetries = 5;

  SyncEngine(this._storageService);

  Future<void> initialize() async {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      // Perform initial sync if online
      final isOnline = await _isConnected();
      if (isOnline) {
        await performSync();
      }

      _logger.i('Sync engine initialized');
    } catch (e) {
      _logger.e('Failed to initialize sync engine: $e');
    }
  }

  /// Perform full synchronization
  Future<void> performSync({bool isManual = false}) async {
    if (_isSyncing) {
      _logger.w('Sync already in progress');
      return;
    }

    // Check connectivity
    if (!await _isConnected()) {
      _logger.w('No connectivity for sync');
      return;
    }

    _isSyncing = true;

    try {
      // Get pending changes
      final pendingChanges = await _storageService.getPendingChanges();

      if (pendingChanges.isEmpty) {
        _logger.i('No pending changes to sync');
        _isSyncing = false;
        return;
      }

      _logger.i('Starting sync of ${pendingChanges.length} changes');

      // Sync each pending change
      for (final change in pendingChanges) {
        try {
          await _syncChange(change);
          await _storageService.markChangeAsSynced(change['id']);
          _retryCount = 0; // Reset retry count on success
        } catch (e) {
          _logger.e('Failed to sync change ${change['id']}: $e');
          // Leave for retry
        }
      }

      _logger.i('Sync completed');
      _isSyncing = false;
    } catch (e) {
      _logger.e('Sync failed: $e');
      _isSyncing = false;

      // Schedule retry
      if (_retryCount < _maxRetries) {
        _scheduleRetry();
      }
    }
  }

  /// Sync individual change
  Future<void> _syncChange(Map<String, dynamic> change) async {
    final tableName = change['table_name'];
    final operation = change['operation'];
    final data = change['data'];

    _logger.i('Syncing $operation to $tableName');

    // TODO: Implement API call to backend
    // This would be replaced with actual HTTP requests
    // For now, we simulate sync with a delay

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Outbox pattern - add change to be synced
  Future<void> addChangeToOutbox({
    required String tableName,
    required String recordId,
    required String operation, // create, update, delete
    required String data,
  }) async {
    try {
      await _storageService.addPendingChange(
        tableName,
        recordId,
        operation,
        data,
      );

      _logger.i('Change added to outbox: $tableName/$recordId/$operation');

      // Attempt immediate sync if online
      if (await _isConnected()) {
        await performSync();
      }
    } catch (e) {
      _logger.e('Failed to add change to outbox: $e');
    }
  }

  /// Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'retryCount': _retryCount,
      'maxRetries': _maxRetries,
    };
  }

  // ==================== Private Methods ====================

  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final isOnline =
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);

    if (isOnline) {
      _logger.i('Connectivity restored');
      _retryTimer?.cancel();
      // Attempt sync
      performSync();
    } else {
      _logger.w('Lost connectivity');
    }
  }

  void _scheduleRetry() {
    _retryCount++;
    final delaySeconds = min(
      pow(2, _retryCount).toInt(),
      300,
    ); // Exponential backoff, max 5 min

    _logger.i(
      'Scheduling sync retry in ${delaySeconds}s (attempt $_retryCount/$_maxRetries)',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isSyncing) {
        performSync();
      }
    });
  }

  /// Vector clock implementation for conflict resolution
  /// Returns true if clock1 happened before clock2
  static bool vectorClockCompare(
    Map<String, int> clock1,
    Map<String, int> clock2,
  ) {
    bool allLessOrEqual = true;
    bool anyLess = false;

    for (final key in clock1.keys) {
      final val1 = clock1[key] ?? 0;
      final val2 = clock2[key] ?? 0;

      if (val1 > val2) {
        allLessOrEqual = false;
        break;
      }
      if (val1 < val2) {
        anyLess = true;
      }
    }

    return allLessOrEqual && anyLess;
  }

  /// Cleanup
  Future<void> dispose() async {
    await _connectivitySubscription.cancel();
    _retryTimer?.cancel();
  }

  bool get isSyncing => _isSyncing;
}
