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
import 'package:offline_survival_companion/services/network/peer_mesh_service.dart';
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
  final PeerMeshService _peerMeshService;
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
    this._peerMeshService,
  ) : super(const AppInitializing()) {
    on<AppInitialized>(_onAppInitialized);
    on<AppResumed>(_onAppResumed);
    on<AppPaused>(_onAppPaused);
    on<SyncRequested>(_onSyncRequested);
    on<BatteryLevelChanged>(_onBatteryLevelChanged);
    on<OnboardingCompleted>(_onOnboardingCompleted);
    on<SurvivalModeToggled>(_onSurvivalModeToggled);
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

      // Initialize sync engine with timeout
      _logger.i('Initializing SyncEngine...');
      await _syncEngine.initialize().timeout(const Duration(seconds: 5), onTimeout: () {
        _logger.w('SyncEngine initialization timed out');
      });

      // Start shake detection
      _shakeDetectorService.start();

      // Ensure a default user exists
      final userId = await _storageService.getOrCreateDefaultUser();

      // Bypass onboarding check - Go straight to home
      _logger.i('App ready, emitting AppReady');
      emit(AppReady(userId: userId));
      
      // Mark as onboarded in storage for future consistency
      await _storageService.saveSetting('is_onboarded', true);
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

      _shakeDetectorService.start();

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
      await _syncEngine.fetchGlobalSafetyPins();
    } catch (e) {
      _logger.e('Sync failed: $e');
    }
  }

  Future<void> _onBatteryLevelChanged(
    BatteryLevelChanged event,
    Emitter<AppState> emit,
  ) async {
    if (event.level <= 20) {
      _logger.w('Low battery level (${event.level}%) detected. Auto-activating Survival Mode.');
      add(const SurvivalModeToggled(true));
    }
  }

  void _onSurvivalModeToggled(
    SurvivalModeToggled event,
    Emitter<AppState> emit,
  ) {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(isSurvivalMode: event.isEnabled));
      _logger.i('Survival Mode ${event.isEnabled ? "Enabled" : "Disabled"}');
    }
  }

  @override
  Future<void> close() async {
    _evidenceService.dispose();
    _trackingService.dispose();
    _shakeDetectorService.stop();
    await _peerMeshService.stopAll();
    await _syncEngine.dispose();
    await _storageService.close();
    await _alarmService.dispose();
    await _emergencyService.dispose();
    return super.close();
  }
}
