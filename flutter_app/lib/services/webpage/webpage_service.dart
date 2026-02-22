import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';

class SavedWebpage {
  final String id;
  final String url;
  final String title;
  final String filePath;
  final DateTime savedAt;

  SavedWebpage({
    required this.id,
    required this.url,
    required this.title,
    required this.filePath,
    required this.savedAt,
  });

  /// Convert to a map for SQLite insertion (matches `saved_web_pages` schema).
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': 'local', // single-user for now
        'title': title,
        'url': url,
        'html_path': filePath,
        'created_at': savedAt.millisecondsSinceEpoch,
      };

  factory SavedWebpage.fromMap(Map<String, dynamic> map) => SavedWebpage(
        id: map['id'] as String,
        url: map['url'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled',
        filePath: map['html_path'] as String? ?? '',
        savedAt: DateTime.fromMillisecondsSinceEpoch(
            (map['created_at'] as int?) ?? 0),
      );
}

class WebpageService {
  final LocalStorageService _storage;
  final Logger _logger = Logger();

  WebpageService({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  /// Download and persist a webpage for offline use.
  Future<SavedWebpage> saveWebpage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      final document = parse(response.body);
      final title =
          document.querySelector('title')?.text.trim() ?? 'Untitled Page';

      // Extract plain text and clean it up
      // We remove script and style tags before extracting text
      document.querySelectorAll('script, style').forEach((s) => s.remove());
      final plainText = document.body?.text.trim() ?? '';
      
      // Clean up multiple newlines/whitespace
      final cleanedText = plainText.replaceAll(RegExp(r'\n\s*\n'), '\n\n');

      // Save as .txt for readability
      final directory = await getApplicationDocumentsDirectory();
      final pageId = const Uuid().v4();
      final filePath = '${directory.path}/offline_pages/$pageId.txt';
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(cleanedText);

      final webpage = SavedWebpage(
        id: pageId,
        url: url,
        title: title,
        filePath: filePath,
        savedAt: DateTime.now(),
      );

      // Persist metadata in SQLite so it survives app restarts
      await _persistPage(webpage);

      _logger.i('Saved webpage: $title');
      return webpage;
    } catch (e) {
      _logger.e('Error saving webpage: $e');
      throw Exception('Error saving webpage: $e');
    }
  }

  /// Load all saved pages from SQLite (persisted across restarts).
  Future<List<SavedWebpage>> getSavedPages() async {
    try {
      if (!_storage.isInitialized) return [];
      final db = _storage.database;
      if (db == null) return [];

      final rows = await db.query(
        'saved_web_pages',
        where: 'user_id = ?',
        whereArgs: ['local'],
        orderBy: 'created_at DESC',
      );
      return rows.map(SavedWebpage.fromMap).toList();
    } catch (e) {
      _logger.e('Failed to load saved pages: $e');
      return [];
    }
  }

  /// Delete a saved page (removes HTML file + DB row).
  Future<void> deletePage(SavedWebpage page) async {
    try {
      // Remove HTML file
      final file = File(page.filePath);
      if (await file.exists()) await file.delete();

      // Remove DB row
      final db = _storage.database;
      if (db != null) {
        await db.delete('saved_web_pages',
            where: 'id = ?', whereArgs: [page.id]);
      }
      _logger.i('Deleted saved page: ${page.title}');
    } catch (e) {
      _logger.e('Failed to delete page: $e');
    }
  }

  /// Load raw HTML content from the saved file.
  Future<String> loadPageContent(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('Saved file not found – the page may have been cleared.');
  }

  // ── private ──────────────────────────────────────────────

  Future<void> _persistPage(SavedWebpage page) async {
    try {
      final db = _storage.database;
      if (db == null) return;
      await db.insert(
        'saved_web_pages',
        page.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Failed to persist page metadata: $e');
    }
  }
}

// Needed for ConflictAlgorithm reference (imported via sqflite transitively)
