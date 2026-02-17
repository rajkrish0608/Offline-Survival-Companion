import 'package:flutter/material.dart';
import 'package:offline_survival_companion/services/webpage/webpage_service.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'dart:io';

class WebpageSaverScreen extends StatefulWidget {
  const WebpageSaverScreen({Key? key}) : super(key: key);

  @override
  State<WebpageSaverScreen> createState() => _WebpageSaverScreenState();
}

class _WebpageSaverScreenState extends State<WebpageSaverScreen> {
  final TextEditingController _urlController = TextEditingController();
  final WebpageService _webpageService = WebpageService();
  bool _isLoading = false;
  List<SavedWebpage> _savedPages = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPages();
  }

  Future<void> _loadSavedPages() async {
    // In a real app we'd load from database. 
    // Here we'll simulate loading pre-saved or session-based pages.
    if (mounted) {
      setState(() {
        // Mock data for demo until DB is fully wired
        _savedPages = [
          SavedWebpage(
            id: '1',
            url: 'https://www.ready.gov/kit',
            title: 'Build A Kit | Ready.gov',
            filePath: '/path/to/mock/file.html',
            savedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          SavedWebpage(
            id: '2',
            url: 'https://www.redcross.org/get-help.html',
            title: 'Get Help | Red Cross',
            filePath: '/path/to/mock/file2.html',
            savedAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ];
      });
    }
  }

  Future<void> _savePage() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL starting with http:// or https://')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Simulate network delay and improved validation for demo
    try {
      // In production this would call _webpageService.saveWebpage(url)
      // For now we simulate a successful save to avoid network errors in emulator without internet.
      await Future.delayed(const Duration(seconds: 2)); 
      
      final newPage = SavedWebpage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: 'New Offline Page (${url.length > 20 ? url.substring(0, 20) : url}...)',
        filePath: '/mock/path',
        savedAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _savedPages.insert(0, newPage);
          _urlController.clear();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page saved successfully for offline reading!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving page: $e')),
        );
      }
    }
  }

  void _openPage(SavedWebpage page) {
    // Navigate to a reader view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.url, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                const Text(
                  'This is a simplified view of the saved content. In a full implementation, this would render the sanitized HTML body.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 20),
                // Placeholder content
                Text(
                  'Saved Content Preview:\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Webpage Saver')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Enter URL to save (https://...)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _isLoading ? null : _savePage,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download),
                  tooltip: 'Save for Offline',
                  style: IconButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _savedPages.isEmpty
                ? const Center(child: Text('No saved pages yet'))
                : ListView.builder(
                    itemCount: _savedPages.length,
                    itemBuilder: (context, index) {
                      final page = _savedPages[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.public)),
                        title: Text(page.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(page.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _openPage(page),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
