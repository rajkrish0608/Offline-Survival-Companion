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
import 'package:offline_survival_companion/services/network/peer_mesh_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web Support: Bypass intensive native-only initialization
  if (kIsWeb) {
    debugPrint('Running on Web: Using mock services for verification...');
    final storageService = LocalStorageService();
    final encryptionService = EncryptionService();
    final evidenceService = EvidenceService(storageService);
    final peerMeshService = PeerMeshService();
    final emergencyService = EmergencyService(
      storageService: storageService,
      evidenceService: evidenceService,
      peerMeshService: peerMeshService,
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
        peerMeshService: peerMeshService,
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

  final peerMeshService = PeerMeshService();
  final evidenceService = EvidenceService(storageService);
  final emergencyService = EmergencyService(
    storageService: storageService,
    evidenceService: evidenceService,
    peerMeshService: peerMeshService,
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
  final voiceSosService = VoiceSosService(emergencyService);

  // Start background listening for P2P Mesh SOS signals
  try {
    peerMeshService.onSosReceived = (payload) {
      debugPrint('CRITICAL ALARM: MESH SOS RECEIVED: $payload');
      // In a real scenario, this would trigger a high-priority local notification
      // or a specific UI alert using a global key.
    };
    await peerMeshService.startDiscovering();
  } catch (e) {
    debugPrint('Failed to start mesh discovery: $e');
  }

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
      peerMeshService: peerMeshService,
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
  final PeerMeshService peerMeshService;

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
    required this.peerMeshService,
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
            peerMeshService,
          )..add(const AppInitialized()),
        ),
        // Providing individual services for easy UI access
        RepositoryProvider.value(value: peerMeshService),
        RepositoryProvider.value(value: storageService),
        ChangeNotifierProvider.value(value: emergencyService),
        RepositoryProvider.value(value: alarmService),
        ChangeNotifierProvider.value(value: safetyTimerService),
        RepositoryProvider.value(value: shakeDetectorService),
        RepositoryProvider.value(value: trackingService),
        RepositoryProvider.value(value: evidenceService),
        ChangeNotifierProvider.value(value: voiceSosService),
      ],
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          bool isSurvival = false;
          if (state is AppReady) {
            isSurvival = state.isSurvivalMode;
          }

          return MaterialApp.router(
            title: 'Offline Survival Companion',
            theme: isSurvival ? AppTheme.survivalTheme : AppTheme.lightTheme,
            darkTheme: isSurvival ? AppTheme.survivalTheme : AppTheme.darkTheme,
            themeMode: isSurvival ? ThemeMode.dark : ThemeMode.dark, // Default to dark, survival is always dark
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
