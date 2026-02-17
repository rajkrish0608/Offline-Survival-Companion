import 'package:flutter/material.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({Key? key}) : super(key: key);

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  // Mock data for offline packs
  final List<Map<String, dynamic>> _regions = [
    {
      'id': 'california',
      'name': 'California, USA',
      'size': '450 MB',
      'status': 'not_downloaded',
      'progress': 0.0
    },
    {
      'id': 'new_york',
      'name': 'New York, USA',
      'size': '320 MB',
      'status': 'not_downloaded',
      'progress': 0.0
    },
    {
      'id': 'london',
      'name': 'London, UK',
      'size': '280 MB',
      'status': 'downloaded',
      'progress': 1.0
    },
    {
      'id': 'tokyo',
      'name': 'Tokyo, Japan',
      'size': '500 MB',
      'status': 'not_downloaded',
      'progress': 0.0
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Maps')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Region...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.wifi, size: 16),
                SizedBox(width: 8),
                Text('Download over Wi-Fi only'),
                Spacer(),
                Switch(value: true, onChanged: null), // Mock toggle
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _regions.length,
              itemBuilder: (context, index) {
                final region = _regions[index];
                return ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(region['name']),
                  subtitle: Text(region['size']),
                  trailing: _buildTrailingWidget(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingWidget(int index) {
    final region = _regions[index];
    final status = region['status'];

    if (status == 'downloading') {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: region['progress'],
          strokeWidth: 3,
        ),
      );
    } else if (status == 'downloaded') {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green),
        onPressed: () => _confirmDelete(index),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => _startDownload(index),
      );
    }
  }

  void _startDownload(int index) async {
    if (!mounted) return;
    setState(() {
      _regions[index]['status'] = 'downloading';
    });

    // Simulate download
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _regions[index]['progress'] = i / 10;
      });
    }

    if (mounted) {
      setState(() {
        _regions[index]['status'] = 'downloaded';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_regions[index]['name']} downloaded'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete ${_regions[index]['name']}?'),
            content: const Text(
              'This will remove the offline map from your device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _regions[index]['status'] = 'not_downloaded';
                    _regions[index]['progress'] = 0.0;
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
