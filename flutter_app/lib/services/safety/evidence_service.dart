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

  EvidenceService(this._storageService);

  Future<void> captureEvidence({required String userId}) async {
    if (_isCapturing) return;
    _isCapturing = true;

    _logger.i('Starting auto-evidence collection for user: $userId');

    try {
      // 1. Capture Photo
      final photoPath = await _capturePhoto();
      if (photoPath != null) {
        await _saveToVault(userId, File(photoPath), 'photo');
      }

      // 2. Start Audio Recording (will run for 30s)
      await _recordAudio(userId);

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

      // Use front camera if available
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

        // Record for 30 seconds
        Timer(const Duration(seconds: 30), () async {
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

  Future<void> _saveToVault(String userId, File file, String type) async {
    try {
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
        'is_encrypted': 1, // Logic for actual encryption happens in VaultScreen/EncryptionService
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      _logger.i('Saved $type evidence to vault: $fileName');
    } catch (e) {
      _logger.e('Failed to save $type to vault: $e');
    }
  }

  String _getFileExtension(String type) {
    return type == 'photo' ? '.jpg' : '.m4a';
  }

  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
  }
}
