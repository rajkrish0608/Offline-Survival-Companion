import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  MapLibreMapController? _mapController;
  bool _showDownloads = false;

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
  void initState() {
    super.initState();
    _checkDownloadedMaps();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        actions: [
          IconButton(
            icon: Icon(_showDownloads ? Icons.map : Icons.download_for_offline),
            onPressed: () => setState(() => _showDownloads = !_showDownloads),
            tooltip: _showDownloads ? 'View Map' : 'Manage Downloads',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Real Map Rendering
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(34.0522, -118.2437), // Los Angeles
              zoom: 12.0,
            ),
            styleString: 'assets/maps/style.json',
            myLocationEnabled: true,
            trackCameraPosition: true,
          ),

          // Search Overlay (Only when map is shown)
          if (!_showDownloads)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search Location...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

          // Offline Downloads List (Shown as an overlay or toggleable screen)
          if (_showDownloads)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.wifi, size: 16),
                        SizedBox(width: 8),
                        Text('Download over Wi-Fi only'),
                        Spacer(),
                        Switch(value: true, onChanged: null),
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
            ),
        ],
      ),
      floatingActionButton: !_showDownloads
          ? FloatingActionButton(
              onPressed: () {
                // Future: Zoom to current location
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(
                        target: LatLng(34.0522, -118.2437), zoom: 15),
                  ),
                );
              },
              backgroundColor: AppTheme.accentBlue,
              child: const Icon(Icons.my_location),
            )
          : null,
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

  Future<void> _checkDownloadedMaps() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        for (var region in _regions) {
          final file = File('${dir.path}/offline_maps/${region['id']}.map');
          if (file.existsSync()) {
            region['status'] = 'downloaded';
            region['progress'] = 1.0;
          }
        }
      });
    } catch (e) {
      // Handle potential errors quietly for now
    }
  }

  Future<void> _startDownload(int index) async {
    if (!mounted) return;
    setState(() {
      _regions[index]['status'] = 'downloading';
    });

    final dir = await getApplicationDocumentsDirectory();
    final mapDir = Directory('${dir.path}/offline_maps');
    if (!await mapDir.exists()) {
      await mapDir.create(recursive: true);
    }

    // Simulate download with progress
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _regions[index]['progress'] = i / 10;
      });
    }

    final file = File('${mapDir.path}/${_regions[index]['id']}.map');
    await file.writeAsString('Dummy map data for ${_regions[index]['name']}');

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
      builder: (context) => AlertDialog(
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
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final file =
                  File('${dir.path}/offline_maps/${_regions[index]['id']}.map');
              if (await file.exists()) {
                await file.delete();
              }

              if (context.mounted) {
                setState(() {
                  _regions[index]['status'] = 'not_downloaded';
                  _regions[index]['progress'] = 0.0;
                });
                Navigator.pop(context);
              }
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
