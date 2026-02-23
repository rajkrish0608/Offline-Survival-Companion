import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/data/models/poi_model.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  MapLibreMapController? _mapController;
  bool _locationPermissionGranted = false;
  bool _showDownloads = false;
  bool _addPinMode = false;
  List<POI> _userPois = [];

  final List<Map<String, dynamic>> _regions = [
    {'name': 'Delhi NCR', 'size': '45 MB', 'status': 'downloaded', 'progress': 1.0},
    {'name': 'London Central', 'size': '120 MB', 'status': 'available', 'progress': 0.0},
    {'name': 'New York City', 'size': '210 MB', 'status': 'downloading', 'progress': 0.65},
    {'name': 'Patna (Bihar)', 'size': '32 MB', 'status': 'available', 'progress': 0.0},
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadUserPois();
  }

  Future<void> _loadUserPois() async {
    final appState = context.read<AppBloc>().state;
    if (appState is AppReady) {
      final storage = context.read<LocalStorageService>();
      final poisData = await storage.getPOIs(appState.userId);
      setState(() {
        _userPois = poisData.map((p) => POI(
          id: p['id'],
          user_id: p['user_id'], // Wait, checking POI model...
          title: p['title'],
          latitude: p['latitude'],
          longitude: p['longitude'],
          type: p['type'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(p['created_at']),
        )).toList();
      });
      _updateMarkers();
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() { _locationPermissionGranted = status.isGranted; });
  }

  final Set<String> _activeCategories = {};

  final List<Map<String, dynamic>> _safePoints = [
    // Patna Points
    {'name': 'Gandhi Maidan Police Station', 'lat': 25.6186, 'lng': 85.1414, 'type': 'police'},
    {'name': 'Patiala House Court Police', 'lat': 25.6100, 'lng': 85.1200, 'type': 'police'},
    {'name': 'PMCH Hospital', 'lat': 25.6210, 'lng': 85.1520, 'type': 'hospital'},
    {'name': 'Ruban Memorial', 'lat': 25.5940, 'lng': 85.1050, 'type': 'hospital'},
    // NYC Points
    {'name': 'NYPD 1st Precinct', 'lat': 40.7230, 'lng': -74.0080, 'type': 'police'},
    {'name': 'Upper East Side Hospital', 'lat': 40.7640, 'lng': -73.9550, 'type': 'hospital'},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_activeCategories.contains(category)) {
        _activeCategories.remove(category);
      } else {
        _activeCategories.add(category);
      }
    });
    _updateMarkers();
  }

  void _updateMarkers() {
    _mapController?.clearSymbols();
    _mapController?.clearCircles();
    
    // Static Safe Points
    for (var point in _safePoints) {
      if (_activeCategories.contains(point['type'])) {
        final color = point['type'] == 'police' ? '#2196F3' : '#F44336';
        _mapController?.addCircle(
          CircleOptions(
            geometry: LatLng(point['lat'], point['lng']),
            circleRadius: 8.0,
            circleColor: color,
            circleBlur: 0.1,
            circleOpacity: 0.8,
            circleStrokeWidth: 2.0,
            circleStrokeColor: '#ffffff',
          ),
        );
      }
    }

    // User Custom POIs
    for (var poi in _userPois) {
      _mapController?.addCircle(
        CircleOptions(
          geometry: LatLng(poi.latitude, poi.longitude),
          circleRadius: 10.0,
          circleColor: _getPoiColor(poi.type),
          circleBlur: 0.0,
          circleOpacity: 1.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#ffffff',
        ),
      );
      // Optional: Add symbol/text label
      _mapController?.addSymbol(
        SymbolOptions(
          geometry: LatLng(poi.latitude, poi.longitude),
          textField: poi.title,
          textOffset: const Offset(0, 2),
          textColor: '#ffffff',
          textSize: 12.0,
          textHaloColor: '#000000',
          textHaloWidth: 1.0,
        ),
      );
    }
  }

  String _getPoiColor(String type) {
    switch (type) {
      case 'water': return '#00BCD4';
      case 'shelter': return '#4CAF50';
      case 'hazard': return '#FF9800';
      default: return '#9C27B0';
    }
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    if (_addPinMode) {
      _showAddPoiDialog(latLng);
    }
  }

  Future<void> _showAddPoiDialog(LatLng latLng) async {
    final titleController = TextEditingController();
    String selectedType = 'other';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Point of Interest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title (e.g. Clean Water)'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'water', child: Text('Water Source')),
                DropdownMenuItem(value: 'shelter', child: Text('Shelter')),
                DropdownMenuItem(value: 'hazard', child: Text('Hazard')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => selectedType = v ?? 'other',
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      _saveNewPoi(titleController.text, selectedType, latLng);
    }
  }

  Future<void> _saveNewPoi(String title, String type, LatLng latLng) async {
    final appState = context.read<AppBloc>().state;
    if (appState is AppReady) {
      final poi = POI(
        id: const Uuid().v4(),
        user_id: appState.userId,
        title: title,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        type: type,
        createdAt: DateTime.now(),
      );

      final storage = context.read<LocalStorageService>();
      await storage.savePOI({
        'id': poi.id,
        'user_id': poi.user_id,
        'title': poi.title,
        'latitude': poi.latitude,
        'longitude': poi.longitude,
        'type': poi.type,
        'created_at': poi.createdAt.millisecondsSinceEpoch,
      });

      setState(() {
        _userPois.add(poi);
        _addPinMode = false;
      });
      _updateMarkers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('POI Saved Successfully')));
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    final q = query.toLowerCase();
    LatLng? target;

    if (q.contains('delhi')) target = const LatLng(28.6139, 77.2090);
    else if (q.contains('london')) target = const LatLng(51.5074, -0.1278);
    else if (q.contains('new york')) target = const LatLng(40.7128, -74.0060);
    else if (q.contains('los angeles')) target = const LatLng(34.0522, -118.2437);
    else if (q.contains('tokyo')) target = const LatLng(35.6762, 139.6503);
    else if (q.contains('patna')) target = const LatLng(25.5941, 85.1376);

    if (target != null) {
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 12)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search index: "$query" not found.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: We removed the Scaffold here because it's used inside HomeScreen's Scaffold body.
    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: _onMapCreated,
          onMapClick: _onMapClick,
          initialCameraPosition: const CameraPosition(target: LatLng(40.7128, -74.0060), zoom: 12.0), // New York
          styleString: "assets/maps/style.json",
          myLocationEnabled: _locationPermissionGranted,
          trackCameraPosition: true,
        ),
        if (!_showDownloads)
          Positioned(
            top: 16, left: 16, right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search (e.g. Patna, NYC)',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: _searchLocation,
                ),
              ),
            ),
          ),
        if (_showDownloads)
          Positioned.fill(
            child: Container(
              color: AppTheme.primaryDark,
              child: Column(
                children: [
                   AppBar(
                    title: const Text('Offline Regions'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _showDownloads = false),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _regions.length,
                      itemBuilder: (context, index) {
                        final region = _regions[index];
                        return ListTile(
                          title: Text(region['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(region['size'], style: const TextStyle(color: Colors.grey)),
                          trailing: region['status'] == 'downloaded' ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.download, color: Colors.blue),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_showDownloads)
          Positioned(
            bottom: 110, left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   _MapLegendItem(
                     icon: Icons.local_police, 
                     color: Colors.blue, 
                     label: 'Police Stations',
                     isActive: _activeCategories.contains('police'),
                     onTap: () => _toggleCategory('police'),
                   ),
                   const SizedBox(height: 8),
                   _MapLegendItem(
                     icon: Icons.local_hospital, 
                     color: Colors.red, 
                     label: 'Hospitals',
                     isActive: _activeCategories.contains('hospital'),
                     onTap: () => _toggleCategory('hospital'),
                   ),
                ],
              ),
            ),
          ),
        // Positioned Location button - moved higher to not conflict with central SOS
        if (!_showDownloads)
          Positioned(
            bottom: 120, right: 16,
            child: FloatingActionButton(
              onPressed: () => _mapController?.animateCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: LatLng(25.5941, 85.1376), zoom: 15))),
              mini: true,
              heroTag: 'maps_loc_fab_fix',
              child: const Icon(Icons.my_location),
            ),
          ),
        // Dedicated Download Trigger Button on Map
        if (!_showDownloads)
          Positioned(
            top: 80, right: 16,
            child: FloatingActionButton(
              onPressed: () => setState(() => _showDownloads = true),
              mini: true,
              backgroundColor: Colors.white,
              heroTag: 'maps_download_trigger',
              child: const Icon(Icons.download_for_offline, color: Colors.blue),
            ),
          ),
        // Add POI Button
        if (!_showDownloads)
          Positioned(
            bottom: 120, right: 70,
            child: FloatingActionButton(
              onPressed: () => setState(() => _addPinMode = !_addPinMode),
              mini: true,
              backgroundColor: _addPinMode ? Colors.red : Colors.green,
              heroTag: 'maps_add_poi_fab',
              child: Icon(_addPinMode ? Icons.close : Icons.add_location_alt),
            ),
          ),
        if (_addPinMode)
          Positioned(
            top: 100, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap on map to add a survival point',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MapLegendItem({
    required this.icon, 
    final Color? color, 
    required this.label,
    required this.isActive,
    required this.onTap,
  }) : color = color ?? Colors.blue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.3) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.white24, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? color : Colors.white70),
            const SizedBox(width: 8),
            Text(
              label, 
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70, 
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
