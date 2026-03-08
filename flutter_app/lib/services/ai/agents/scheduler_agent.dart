import 'package:offline_survival_companion/services/ai/core/agent_base.dart';
import 'package:offline_survival_companion/services/ai/core/agent_result.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';

enum SchedulerAction {
  scheduleMedication,
  schedulePing,
  scheduleWaterRation,
  cancelAll
}

class SchedulerAgent extends AgentBase {
  final Logger _logger = Logger();
  final LocalStorageService _storageService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  @override
  String get agentName => 'Intelligent Scheduler Agent';

  SchedulerAgent({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  Future<void> initialize() async {
    if (_initialized) return;

    // Standard local notification setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _notificationsPlugin.initialize(initializationSettings);

    // Initializing background workmanager
    try {
      Workmanager().initialize(
        _callbackDispatcher, 
        isInDebugMode: true,
      );
      _initialized = true;
      _logger.i('Agent 11 (Scheduler) initialized with WorkManager.');
    } catch (e) {
      _logger.e('Failed to initialize WorkManager for Agent 11: $e');
    }
  }

  @override
  Future<AgentResult> execute(Map<String, dynamic> params) async {
    updateStatus(AgentStatus.running);
    
    if (!_initialized) {
      await initialize();
    }

    final String actionStr = params['action'] as String? ?? '';
    final action = _parseAction(actionStr);

    try {
      switch (action) {
        case SchedulerAction.scheduleMedication:
          final medName = params['medication'] ?? 'Medicine';
          final hours = params['interval_hours'] ?? 8;
          await _schedulePeriodicTask(
            taskName: 'medication_reminder_$medName',
            intervalMinutes: (hours * 60).toInt(),
            data: {'type': 'medication', 'message': 'Time to take: $medName'},
          );
          _logger.i('Scheduled medication: $medName every $hours hours.');
          updateStatus(AgentStatus.success);
          return AgentResult.success(message: 'Medication schedule activated for $medName');

        case SchedulerAction.schedulePing:
          await _schedulePeriodicTask(
            taskName: 'safety_ping',
            intervalMinutes: 120, // 2 hours
            data: {'type': 'ping', 'message': 'Auto safety ping.'},
          );
          updateStatus(AgentStatus.success);
          return AgentResult.success(message: 'Offline safety background protocol active.');

        case SchedulerAction.scheduleWaterRation:
          await _schedulePeriodicTask(
            taskName: 'water_ration',
            intervalMinutes: 60, // 1 hour
            data: {'type': 'water', 'message': 'Hydration mandatory. Consume 200ml water.'},
          );
          updateStatus(AgentStatus.success);
          return AgentResult.success(message: 'Water rationing schedule applied.');

        case SchedulerAction.cancelAll:
          await Workmanager().cancelAll();
          updateStatus(AgentStatus.success);
          return AgentResult.success(message: 'All scheduled agent tasks cancelled.');

        default:
          updateStatus(AgentStatus.error);
          return AgentResult.fail(message: 'Unknown schedule action provided.');
      }
    } catch (e) {
      _logger.e('Agent 11 execution failed: $e');
      updateStatus(AgentStatus.error);
      return AgentResult.fail(message: 'Scheduling failed: $e');
    }
  }

  SchedulerAction _parseAction(String actionStr) {
    switch (actionStr) {
      case 'medication': return SchedulerAction.scheduleMedication;
      case 'ping': return SchedulerAction.schedulePing;
      case 'water': return SchedulerAction.scheduleWaterRation;
      case 'cancel_all': return SchedulerAction.cancelAll;
      default: return SchedulerAction.schedulePing;
    }
  }

  Future<void> _schedulePeriodicTask({
    required String taskName,
    required int intervalMinutes,
    required Map<String, dynamic> data,
  }) async {
    await Workmanager().registerPeriodicTask(
      taskName, // Unique ID
      taskName, // Background matching name
      frequency: Duration(minutes: intervalMinutes < 15 ? 15 : intervalMinutes), // Android min is 15
      inputData: data,
    );
  }
}

// Background headless dart isolate
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // In actual production, show notification or sync data
    print("Agent 11 Background Task Executing: \$taskName");
    print("Data payload: \$inputData");
    
    // Simplistic notification firing from background
    final FlutterLocalNotificationsPlugin np = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'agent_11_channel',
      'Agent Background Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    if (inputData != null) {
      await np.show(
        taskName.hashCode,
        'Survival Agent Update',
        inputData['message'] ?? 'Background task completed',
        const NotificationDetails(android: androidDetails),
      );
    }

    return Future.value(true);
  });
}
