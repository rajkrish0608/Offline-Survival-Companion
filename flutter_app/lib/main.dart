import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:offline_survival_companion/core/encryption/encryption_service.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:offline_survival_companion/services/audio/alarm_service.dart';
import 'package:offline_survival_companion/services/sync/sync_engine.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/navigation/app_router.dart';
import 'package:offline_survival_companion/services/safety/safety_timer_service.dart';
import 'package:offline_survival_companion/services/safety/shake_detector_service.dart';
import 'package:offline_survival_companion/services/navigation/tracking_service.dart';
import 'package:offline_survival_companion/services/safety/evidence_service.dart';
import 'package:offline_survival_companion/services/safety/voice_sos_service.dart';
import 'package:provider/provider.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web Support: Bypass intensive native-only initialization
  if (kIsWeb) {
    debugPrint('Running on Web: Using mock services for verification...');
    final storageService = LocalStorageService();
    final encryptionService = EncryptionService();
    final evidenceService = EvidenceService(storageService);
    final emergencyService = EmergencyService(
      storageService: storageService,
      evidenceService: evidenceService,
    );
    final alarmService = AlarmService();
    final syncEngine = SyncEngine(storageService);
    final safetyTimerService = SafetyTimerService(emergencyService);
    final shakeDetectorService = ShakeDetectorService(emergencyService);
    final trackingService = TrackingService(storageService);
    final voiceSosService = VoiceSosService(emergencyService);

    runApp(
      OfflineSurvivalApp(
        storageService: storageService,
        encryptionService: encryptionService,
        emergencyService: emergencyService,
        alarmService: alarmService,
        syncEngine: syncEngine,
        safetyTimerService: safetyTimerService,
        shakeDetectorService: shakeDetectorService,
        trackingService: trackingService,
        evidenceService: evidenceService,
        voiceSosService: voiceSosService,
      ),
    );
    return;
  }

  try {
    await dotenv.load().timeout(const Duration(seconds: 1));
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }
  try {
    await Hive.initFlutter().timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('Failed to initialize Hive: $e');
  }

  final storageService = LocalStorageService();
  try {
    await storageService.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Failed to initialize storage service (or timed out): $e');
  }

  final encryptionService = EncryptionService();
  try {
    await encryptionService.initialize().timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('Failed to initialize encryption service (or timed out): $e');
  }

  final evidenceService = EvidenceService(storageService);
  final emergencyService = EmergencyService(
    storageService: storageService,
    evidenceService: evidenceService,
  );
  try {
    await emergencyService.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Failed to initialize emergency service (or timed out): $e');
  }

  final alarmService = AlarmService();
  
  final syncEngine = SyncEngine(storageService);
  final safetyTimerService = SafetyTimerService(emergencyService);
  final shakeDetectorService = ShakeDetectorService(emergencyService);
  final trackingService = TrackingService(storageService);
  final evidenceService = EvidenceService(storageService);
  final voiceSosService = VoiceSosService(emergencyService);

  debugPrint('Calling runApp...');
  runApp(
    OfflineSurvivalApp(
      storageService: storageService,
      encryptionService: encryptionService,
      emergencyService: emergencyService,
      alarmService: alarmService,
      syncEngine: syncEngine,
      safetyTimerService: safetyTimerService,
      shakeDetectorService: shakeDetectorService,
      trackingService: trackingService,
      evidenceService: evidenceService,
      voiceSosService: voiceSosService,
    ),
  );
}

class OfflineSurvivalApp extends StatelessWidget {
  final LocalStorageService storageService;
  final EncryptionService encryptionService;
  final EmergencyService emergencyService;
  final AlarmService alarmService;
  final SyncEngine syncEngine;
  final SafetyTimerService safetyTimerService;
  final ShakeDetectorService shakeDetectorService;
  final TrackingService trackingService;
  final EvidenceService evidenceService;
  final VoiceSosService voiceSosService;

  const OfflineSurvivalApp({
    super.key,
    required this.storageService,
    required this.encryptionService,
    required this.emergencyService,
    required this.alarmService,
    required this.syncEngine,
    required this.safetyTimerService,
    required this.shakeDetectorService,
    required this.trackingService,
    required this.evidenceService,
    required this.voiceSosService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (_) => AppBloc(
            storageService,
            encryptionService,
            emergencyService,
            alarmService,
            syncEngine,
            shakeDetectorService,
            trackingService,
            evidenceService,
            voiceSosService,
          )..add(const AppInitialized()),
        ),
        // Providing individual services for easy UI access
        RepositoryProvider.value(value: storageService),
        RepositoryProvider.value(value: emergencyService),
        RepositoryProvider.value(value: alarmService),
        ChangeNotifierProvider.value(value: safetyTimerService),
        RepositoryProvider.value(value: shakeDetectorService),
        RepositoryProvider.value(value: trackingService),
        RepositoryProvider.value(value: evidenceService),
        RepositoryProvider.value(value: voiceSosService),
      ],
      child: MaterialApp.router(
        title: 'Offline Survival Companion',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
