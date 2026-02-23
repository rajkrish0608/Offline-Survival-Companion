import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:offline_survival_companion/core/encryption/encryption_service.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:offline_survival_companion/services/audio/alarm_service.dart';
import 'package:offline_survival_companion/services/sync/sync_engine.dart';
import 'package:offline_survival_companion/services/safety/shake_detector_service.dart';
import 'package:offline_survival_companion/services/navigation/tracking_service.dart';
import 'package:offline_survival_companion/services/safety/evidence_service.dart';
import 'package:offline_survival_companion/services/safety/voice_sos_service.dart';
import 'package:logger/logger.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final LocalStorageService _storageService;
  final EncryptionService _encryptionService;
  final EmergencyService _emergencyService;
  final AlarmService _alarmService;
  final SyncEngine _syncEngine;
  final ShakeDetectorService _shakeDetectorService;
  final TrackingService _trackingService;
  final EvidenceService _evidenceService;
  final VoiceSosService _voiceSosService;
  final Logger _logger = Logger();

  AppBloc(
    this._storageService,
    this._encryptionService,
    this._emergencyService,
    this._alarmService,
    this._syncEngine,
    this._shakeDetectorService,
    this._trackingService,
    this._evidenceService,
    this._voiceSosService,
  ) : super(const AppInitializing()) {
    on<AppInitialized>(_onAppInitialized);
    on<AppResumed>(_onAppResumed);
    on<AppPaused>(_onAppPaused);
    on<SyncRequested>(_onSyncRequested);
    on<BatteryLevelChanged>(_onBatteryLevelChanged);
    on<OnboardingCompleted>(_onOnboardingCompleted);
  }

  Future<void> _onAppInitialized(
    AppInitialized event,
    Emitter<AppState> emit,
  ) async {
    try {
      _logger.i('Initializing app...');
      
      if (kIsWeb) {
        _logger.i('Running on Web: Bypassing local database init.');
        emit(const AppReady(userId: 'guest_web'));
        return;
      }

      // Initialize sync engine
      await _syncEngine.initialize();

      // Start shake detection
      _shakeDetectorService.start();

      // Ensure a default user exists
      final userId = await _storageService.getOrCreateDefaultUser();

      // Check if user is onboarded
      final isOnboarded = _storageService.isInitialized
          ? (_storageService.getSetting('is_onboarded') ?? false)
          : false;

      if (isOnboarded) {
        emit(AppReady(userId: userId));
      } else {
        emit(const AppOnboardingRequired());
      }
    } catch (e) {
      _logger.e('App initialization failed: $e');
      emit(AppError(message: 'Failed to initialize app: $e'));
    }
  }

  Future<void> _onOnboardingCompleted(
    OnboardingCompleted event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _storageService.saveSetting('is_onboarded', true);
      final userId = await _storageService.getOrCreateDefaultUser();
      emit(AppReady(userId: userId));
    } catch (e) {
      _logger.e('Onboarding completion failed: $e');
    }
  }

  Future<void> _onAppResumed(AppResumed event, Emitter<AppState> emit) async {
    try {
      // Start sync engine
      if (!_syncEngine.isSyncing) {
        await _syncEngine.performSync();
      }

      // Restart shake detection if it was stopped
      // The userId is not directly available in AppResumed,
      // so we need to retrieve it from the current state or storage.
      // Assuming AppReady state holds the userId.
      String userId = 'guest'; // Default or retrieve from storage if not in state
      if (state is AppReady) {
        userId = (state as AppReady).userId;
      } else {
        userId = await _storageService.getOrCreateDefaultUser();
      }

      await _shakeDetectorService.initialize();
      _shakeDetectorService.start(_emergencyService, userId: userId);

      // Initialize Voice SOS
      await _voiceSosService.initialize(userId: userId);

      _logger.i('App resumed');
    } catch (e) {
      _logger.e('Failed to resume app: $e');
    }
  }

  Future<void> _onAppPaused(AppPaused event, Emitter<AppState> emit) async {
    try {
      _logger.i('App paused');
      // We keep shake detector running in background if possible, 
      // but on mobile sensors might stop. 
    } catch (e) {
      _logger.e('Failed to pause app: $e');
    }
  }

  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _syncEngine.performSync(isManual: true);
    } catch (e) {
      _logger.e('Sync failed: $e');
    }
  }

  Future<void> _onBatteryLevelChanged(
    BatteryLevelChanged event,
    Emitter<AppState> emit,
  ) async {
    final isLowBattery = await _emergencyService.isLowBattery();
    if (isLowBattery) {
      _logger.w('Low battery mode activated');
    }
  }

  @override
  Future<void> close() async {
    _evidenceService.dispose();
    _trackingService.dispose();
    _shakeDetectorService.stop();
    await _syncEngine.dispose();
    await _storageService.close();
    await _alarmService.dispose();
    await _emergencyService.dispose();
    return super.close();
  }
}
