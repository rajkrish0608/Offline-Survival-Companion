import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  late Future<List<dynamic>> _guidesFuture;

  @override
  void initState() {
    super.initState();
    _guidesFuture = _loadGuides();
  }

  Future<List<dynamic>> _loadGuides() async {
    try {
      final String response = await rootBundle.loadString('assets/data/guide_content.json');
      final data = await json.decode(response);
      return data;
    } catch (e) {
      debugPrint('Error loading guides: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Survival Guides')),
      body: FutureBuilder<List<dynamic>>(
        future: _guidesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading guides: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No guides available offline.'),
                ],
              ),
            );
          }

          final guides = snapshot.data!;
          return ListView.builder(
            itemCount: guides.length,
            itemBuilder: (context, index) {
              final guide = guides[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(guide['category']).withOpacity(0.2),
                    child: Icon(_getCategoryIcon(guide['category']), color: _getCategoryColor(guide['category'])),
                  ),
                  title: Text(
                    guide['title'], 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(guide['category'] ?? 'General'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      child: Text(
                        guide['content'],
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'First Aid':
        return Icons.medical_services;
      case 'Survival':
        return Icons.landscape;
      case 'Wild Identification':
        return Icons.eco;
      default:
        return Icons.article;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'First Aid':
        return Colors.red;
      case 'Survival':
        return Colors.green;
      case 'Wild Identification':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
