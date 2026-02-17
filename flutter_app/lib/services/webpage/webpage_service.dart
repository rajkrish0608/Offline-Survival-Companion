import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

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
}

class WebpageService {
  Future<SavedWebpage> saveWebpage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      final document = parse(response.body);
      final title = document.querySelector('title')?.text.trim() ?? 'Untitled Page';
      
      // Basic sanitization/optimization could go here
      // For now, we save the raw body
      final directory = await getApplicationDocumentsDirectory();
      final pageId = const Uuid().v4();
      final filePath = '${directory.path}/offline_pages/$pageId.html';
      final file = File(filePath);
      
      await file.create(recursive: true);
      await file.writeAsString(response.body);

      return SavedWebpage(
        id: pageId,
        url: url,
        title: title,
        filePath: filePath,
        savedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error saving webpage: $e');
    }
  }

  Future<List<SavedWebpage>> getSavedPages() async {
    // In a real app, we'd query a database. 
    // For this mockup, we'll scan the directory and return dummy/simulated data 
    // or we could persist metadata to a JSON file.
    // Let's implement a simple file-based metadata storage for persistence.
    return []; // Placeholder for now, typically backed by Hive/SQLite
  }
  
  Future<String> loadPageContent(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('File not found');
  }
}
