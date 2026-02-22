import 'package:flutter/material.dart';
import 'package:offline_survival_companion/services/webpage/webpage_service.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class WebpageSaverScreen extends StatefulWidget {
  const WebpageSaverScreen({super.key});

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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPages() async {
    // Load only actually-saved pages from the service (no mock data)
    final pages = await _webpageService.getSavedPages();
    if (mounted) {
      setState(() {
        _savedPages = pages;
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

    try {
      final newPage = await _webpageService.saveWebpage(url);

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

  void _deletePage(SavedWebpage page) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Remove "${page.title}" from offline storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _savedPages.remove(page));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Page removed.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openPage(SavedWebpage page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page.title)),
          body: FutureBuilder<String>(
            future: _webpageService.loadPageContent(page.filePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading page: ${snapshot.error}'));
              }

              return SingleChildScrollView(
                // Explicit physics ensures scrolling always works on iOS
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(page.url, style: const TextStyle(color: Colors.grey)),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(snapshot.data ?? 'No content available'),
                  ],
                ),
              );
            },
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
                    keyboardType: TextInputType.url,
                    autocorrect: false,
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.web_asset_off, size: 56, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No saved pages yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Paste a URL above and tap download',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                // RefreshIndicator allows pull-to-refresh to reload from service
                : RefreshIndicator(
                    onRefresh: _loadSavedPages,
                    child: ListView.builder(
                      // AlwaysScrollableScrollPhysics ensures the list can
                      // scroll even when there are few items (fixes iOS scroll bug)
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _savedPages.length,
                      itemBuilder: (context, index) {
                        final page = _savedPages[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentBlue.withOpacity(0.15),
                            child: const Icon(Icons.public),
                          ),
                          title: Text(
                            page.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                page.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Saved ${_formatDate(page.savedAt)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                onPressed: () => _deletePage(page),
                                tooltip: 'Delete',
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () => _openPage(page),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
