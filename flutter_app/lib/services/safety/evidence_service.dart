import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class EvidenceService {
  final LocalStorageService _storageService;
  final Logger _logger = Logger();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  CameraController? _cameraController;
  bool _isCapturing = false;
  Timer? _audioTimer;
  bool _stopRequested = false;

  EvidenceService(this._storageService);

  Future<void> captureEvidence({required String userId}) async {
    if (_isCapturing) return;
    _isCapturing = true;
    _stopRequested = false;

    _logger.i('Starting auto-evidence collection for user: $userId');

    try {
      // 1. Capture Photo
      final photoPath = await _capturePhoto();
      if (photoPath != null) {
        await _saveToVault(userId, File(photoPath), 'photo');
      }

      // 2. Start Audio Recording (will run for 15s)
      if (!_stopRequested) await _recordAudio(userId);

      // 3. Start Video Recording (will run for 15s)
      // We wait a bit to ensure camera is free from photo capture
      await Future.delayed(const Duration(seconds: 2));
      if (!_stopRequested) await _recordVideo(userId);

    } catch (e) {
      _logger.e('Failed to capture evidence: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<String?> _capturePhoto() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;

      // Use back camera for better quality photos generally, 
      // but front might be better for 'witness' capture.
      // Front is safer for silent 'selfie' evidence.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      final XFile image = await _cameraController!.takePicture();
      
      await _cameraController!.dispose();
      _cameraController = null;

      return image.path;
    } catch (e) {
      _logger.e('Photo capture failed: $e');
      return null;
    }
  }

  Future<void> _recordAudio(String userId) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/sos_audio_${const Uuid().v4()}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        _logger.i('Audio recording started...');

        // Record for 15 seconds
        _audioTimer = Timer(const Duration(seconds: 15), () async {
          if (_stopRequested) return;
          final audioPath = await _audioRecorder.stop();
          if (audioPath != null) {
            await _saveToVault(userId, File(audioPath), 'audio');
            _logger.i('Audio evidence saved.');
          }
        });
      }
    } catch (e) {
      _logger.e('Audio recording failed: $e');
    }
  }

  Future<void> _recordVideo(String userId) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.low, // Low res to keep file size offline-friendly
        enableAudio: true,
      );

      await _cameraController!.initialize();
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/sos_video_${const Uuid().v4()}.mp4';

      await _cameraController!.startVideoRecording();
      _logger.i('Video recording started...');

      // Record for 15 seconds with periodic checks for stop request
      for (int i = 0; i < 15; i++) {
        if (_stopRequested) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      final XFile videoFile = await _cameraController!.stopVideoRecording();
      await _cameraController!.dispose();
      _cameraController = null;

      await _saveToVault(userId, File(videoFile.path), 'video');
      _logger.i('Video evidence saved to vault.');

    } catch (e) {
      _logger.e('Video recording failed: $e');
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
    }
  }

  Future<void> _saveToVault(String userId, File file, String type) async {
    try {
      if (!await file.exists()) {
        _logger.e('File does not exist: ${file.path}');
        return;
      }

      final vaultDir = await _storageService.getVaultDirectory();
      final fileName = 'evidence_${type}_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(type)}';
      final newPath = '${vaultDir.path}/$fileName';

      await file.copy(newPath);
      await file.delete(); // Cleanup temp

      // Save metadata to DB
      await _storageService.saveVaultDocument({
        'id': const Uuid().v4(),
        'user_id': userId,
        'file_name': fileName,
        'file_path': newPath,
        'category': 'evidence',
        'document_type': type,
        'size_bytes': await File(newPath).length(),
        'is_encrypted': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      _logger.i('Saved $type evidence to vault: $fileName');
    } catch (e) {
      _logger.e('Failed to save $type to vault: $e');
    }
  }

  String _getFileExtension(String type) {
    if (type == 'photo') return '.jpg';
    if (type == 'video') return '.mp4';
    return '.m4a';
  }

  Future<void> stopCapture() async {
    _logger.i('Stopping evidence capture...');
    _stopRequested = true;
    _audioTimer?.cancel();
    
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      
      if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
        await _cameraController!.stopVideoRecording();
      }
    } catch (e) {
      _logger.e('Error during stopCapture: $e');
    } finally {
      _isCapturing = false;
    }
  }

  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
  }
}
