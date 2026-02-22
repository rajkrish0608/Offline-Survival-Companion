import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  MapLibreMapController? _mapController;
  bool _showDownloads = false;
  bool _locationPermissionGranted = false;

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
    _checkPermissions();
    _checkDownloadedMaps();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.location.request();
    if (mounted) {
      setState(() {
        _locationPermissionGranted = status.isGranted;
      });
    }
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
            myLocationEnabled: _locationPermissionGranted,
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
                      hintText: 'Search (e.g. Delhi, London)',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) => _searchLocation(value),
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
              heroTag: 'maps_loc_fab',
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

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    final q = query.toLowerCase();
    LatLng? target;

    if (q.contains('delhi')) {
      target = const LatLng(28.6139, 77.2090);
    } else if (q.contains('london')) {
      target = const LatLng(51.5074, -0.1278);
    } else if (q.contains('new york') || q.contains('nyc')) {
      target = const LatLng(40.7128, -74.0060);
    } else if (q.contains('los angeles') || q.contains('la')) {
      target = const LatLng(34.0522, -118.2437);
    } else if (q.contains('tokyo')) {
      target = const LatLng(35.6762, 139.6503);
    }

    if (target != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 12),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline search: "$query" not found in local index.')),
        );
      }
    }
  }

  Future<void> _checkDownloadedMaps() async {
    final storage = context.read<LocalStorageService>();
    final downloadedPacks = await storage.getDownloadedPacks();
    
    if (mounted) {
      setState(() {
        for (var region in _regions) {
          final isDownloaded = downloadedPacks.any((p) => p['region_id'] == region['id']);
          if (isDownloaded) {
            region['status'] = 'downloaded';
            region['progress'] = 1.0;
          } else {
            region['status'] = 'not_downloaded';
            region['progress'] = 0.0;
          }
        }
      });
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

    // Save to Database
    final storage = context.read<LocalStorageService>();
    await storage.savePack({
      'id': _regions[index]['id'],
      'region_id': _regions[index]['id'],
      'name': _regions[index]['name'],
      'size_mb': int.tryParse(_regions[index]['size'].split(' ')[0]) ?? 0,
      'downloaded': 1,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      'path': file.path,
    });

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

              // Remove from Database
              final storage = context.read<LocalStorageService>();
              await storage.deletePack(_regions[index]['id']);

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
