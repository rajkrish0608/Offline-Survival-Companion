import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class AdminService {
  final LocalStorageService _storage;
  final Logger _logger = Logger();

  AdminService(this._storage);

  /// Returns the 4 aggregated KPIs for the admin analytics tab.
  /// No individual row data is returned.
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      return await _storage.getAdminAnalytics();
    } catch (e) {
      _logger.e('getAnalytics failed: $e');
      return {
        'total_sos_today': 0,
        'top_feature': '—',
        'avg_survival_duration_ms': null,
        'active_devices': 0,
      };
    }
  }

  /// Returns all vault documents joined with owner username.
  Future<List<Map<String, dynamic>>> getVaultFiles() async {
    try {
      return await _storage.getVaultDocumentsAdmin();
    } catch (e) {
      _logger.e('getVaultFiles failed: $e');
      return [];
    }
  }

  /// Returns list of all registered users (id, name, email only).
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      return await _storage.getUsersAll();
    } catch (e) {
      _logger.e('getAllUsers failed: $e');
      return [];
    }
  }

  /// Generates a legal evidence package ZIP for [userId].
  /// Returns the path to the generated ZIP file, or null if no data found.
  Future<String?> exportUserData(String userId) async {
    try {
      final user = await _storage.getUser(userId);
      if (user == null) return null;

      final vaultDocs = await _storage.getVaultDocuments(userId);
      final sosArchives = await _storage.getSosArchives(userId);

      // Collect only existing files
      final existingFiles = <File>[];
      for (final doc in vaultDocs) {
        final f = File(doc['file_path'] as String? ?? '');
        if (await f.exists()) existingFiles.add(f);
      }

      // Build manifest content
      final manifestBuffer = StringBuffer();
      manifestBuffer.writeln('=== LEGAL EVIDENCE PACKAGE ===');
      manifestBuffer.writeln('User ID   : $userId');
      manifestBuffer.writeln('User Name : ${user['name'] ?? 'Unknown'}');
      manifestBuffer.writeln('User Email: ${user['email'] ?? 'Unknown'}');
      manifestBuffer.writeln(
          'Generated : ${DateTime.now().toUtc().toIso8601String()} UTC');
      manifestBuffer.writeln('');
      manifestBuffer.writeln('--- VAULT FILES ---');

      final encoder = ZipFileEncoder();
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/legal_export_${userId}_'
          '${DateTime.now().millisecondsSinceEpoch}.zip';
      encoder.create(zipPath);

      for (final f in existingFiles) {
        final bytes = await f.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        final fname = f.uri.pathSegments.last;
        manifestBuffer.writeln('  $fname  SHA256: $hash');
        encoder.addFile(f, 'vault/$fname');
      }

      manifestBuffer.writeln('');
      manifestBuffer.writeln('--- SOS ARCHIVES ---');
      for (final sos in sosArchives) {
        manifestBuffer.writeln('  Timestamp : ${sos['timestamp']}');
        manifestBuffer.writeln('  Location  : ${sos['lat']}, ${sos['lng']}');
        manifestBuffer.writeln('  Message   : ${sos['full_message']}');
        manifestBuffer.writeln('');
      }

      // Write manifest as a temp file then add to ZIP
      final manifestFile =
          File('${tempDir.path}/manifest.txt');
      await manifestFile.writeAsString(manifestBuffer.toString());
      encoder.addFile(manifestFile, 'manifest.txt');

      encoder.close();
      await manifestFile.delete();

      _logger.i('Legal export generated: $zipPath');
      return zipPath;
    } catch (e) {
      _logger.e('exportUserData failed: $e');
      return null;
    }
  }
}
