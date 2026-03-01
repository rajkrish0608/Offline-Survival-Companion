import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/data/models/poi_model.dart';
import 'package:offline_survival_companion/data/models/safety_pin_model.dart';
import 'package:offline_survival_companion/data/models/route_model.dart';
import 'package:offline_survival_companion/services/navigation/tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  MapLibreMapController? _mapController;
  bool _addPinMode = false;
  bool _addSafetyPinMode = false;
  List<POI> _userPois = [];
  List<SafetyPin> _safetyPins = [];
  bool _isTopoMode = false;
  bool _showDownloads = false;
  bool _locationPermissionGranted = false;
  
  TrackingService? _trackingService;
  StreamSubscription<SurvivalRoute?>? _trackingSubscription;
  SurvivalRoute? _activeRoute;

  List<Map<String, dynamic>> _regions = [
    {'name': 'Delhi NCR', 'size': '45 MB', 'status': 'available', 'progress': 0.0},
    {'name': 'London Central', 'size': '120 MB', 'status': 'available', 'progress': 0.0},
    {'name': 'New York City', 'size': '210 MB', 'status': 'available', 'progress': 0.0},
    {'name': 'Patna (Bihar)', 'size': '32 MB', 'status': 'available', 'progress': 0.0},
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadUserPois();
    _loadSafetyPins();
    _loadPersistedRegions();
  }

  Future<void> _loadPersistedRegions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? regionsJson = prefs.getString('offline_map_regions');
    if (regionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(regionsJson);
        setState(() {
          _regions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } catch (e) {
        // Fallback to default if parsing fails
      }
    }
  }

  Future<void> _savePersistedRegions() async {
    final prefs = await SharedPreferences.getInstance();
    // Reset any 'downloading' states back to 'available' on save to prevent getting stuck
    final safeRegions = _regions.map((r) {
      if (r['status'] == 'downloading') {
        return {...r, 'status': 'available', 'progress': 0.0};
      }
      return r;
    }).toList();
    await prefs.setString('offline_map_regions', jsonEncode(safeRegions));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trackingService ??= context.read<TrackingService>();
    _trackingSubscription ??= _trackingService?.activeRouteStream.listen((route) {
      setState(() {
        _activeRoute = route;
      });
      _updateMarkers(); // This will now also call _drawRoute
    });
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPois() async {
    final appState = context.read<AppBloc>().state;
    if (appState is AppReady) {
      final storage = context.read<LocalStorageService>();
      final poisData = await storage.getPOIs(appState.userId);
      setState(() {
        _userPois = poisData.map((p) => POI(
          id: p['id'],
          user_id: p['user_id'],
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

  Future<void> _loadSafetyPins() async {
    final storage = context.read<LocalStorageService>();
    final pinsData = await storage.getSafetyPins();
    setState(() {
      _safetyPins = pinsData.map((p) => SafetyPin.fromJson(p)).toList();
    });
    _updateMarkers();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() { _locationPermissionGranted = status.isGranted; });
  }

  final Set<String> _activeCategories = {'police', 'hospital'};

  final List<Map<String, dynamic>> _safePoints = [
    // Patna (Bihar) Points
    {'name': 'Gandhi Maidan Police Station', 'lat': 25.6186, 'lng': 85.1414, 'type': 'police'},
    {'name': 'PMCH Hospital', 'lat': 25.6210, 'lng': 85.1520, 'type': 'hospital'},
    {'name': 'Ruban Memorial', 'lat': 25.5940, 'lng': 85.1050, 'type': 'hospital'},

    // Mumbai Points
    {'name': 'Mumbai Central Police', 'lat': 18.9696, 'lng': 72.8193, 'type': 'police'},
    {'name': 'Sir H. N. Reliance Hospital', 'lat': 18.9592, 'lng': 72.8210, 'type': 'hospital'},
    {'name': 'JJ Hospital', 'lat': 18.9633, 'lng': 72.8339, 'type': 'hospital'},

    // Delhi Points
    {'name': 'New Delhi Rly Stn Police', 'lat': 28.6429, 'lng': 77.2190, 'type': 'police'},
    {'name': 'AIIMS Delhi', 'lat': 28.5672, 'lng': 77.2100, 'type': 'hospital'},
    {'name': 'Safdarjung Hospital', 'lat': 28.5670, 'lng': 77.2078, 'type': 'hospital'},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    // Trigger marker rendering now that the controller is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _updateMarkers();
    });
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
    }

    // Safety Pins (Crowdsourced)
    for (var pin in _safetyPins) {
      final isGlobal = pin.userId == 'system';
      _mapController?.addCircle(
        CircleOptions(
          geometry: LatLng(pin.latitude, pin.longitude),
          circleRadius: isGlobal ? 14.0 : 12.0,
          circleColor: _getSafetyPinColor(pin.category),
          circleOpacity: 0.9,
          circleStrokeWidth: isGlobal ? 3.0 : 2.0,
          circleStrokeColor: isGlobal ? '#FFFFFF' : '#000000',
        ),
      );
      // Removed the addSymbol call that was failing due to missing 'marker-15' icon in the offline style.
      // Instead, we just rely on the colored circle above.
    }

    _drawRoute();
  }

  String _getPoiColor(String type) {
    switch (type) {
      case 'water': return '#00BCD4';
      case 'shelter': return '#4CAF50';
      case 'hazard': return '#FF9800';
      default: return '#9C27B0';
    }
  }

  String _getSafetyPinColor(String category) {
    switch (category) {
      case 'hazard': return '#FF5252'; // Red
      case 'lighting': return '#FFD700'; // Gold
      case 'safe-haven': return '#4CAF50'; // Green
      default: return '#9E9E9E'; // Grey
    }
  }

  String _getSafetyPinIcon(String category) {
    // These should match images pre-registered in the map controller
    // For now using simple strings.
    return 'marker-15';
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    if (_addPinMode) {
      _showAddPoiDialog(latLng);
    } else if (_addSafetyPinMode) {
      _showAddSafetyPinDialog(latLng);
    }
  }

  Future<void> _showAddSafetyPinDialog(LatLng latLng) async {
    final descController = TextEditingController();
    String selectedCategory = 'hazard';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Safety Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              items: const [
                DropdownMenuItem(value: 'hazard', child: Text('Hazard/Danger')),
                DropdownMenuItem(value: 'lighting', child: Text('Poor Lighting')),
                DropdownMenuItem(value: 'safe-haven', child: Text('Safe Haven')),
              ],
              onChanged: (v) => selectedCategory = v ?? 'hazard',
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Report')),
        ],
      ),
    );

    if (result == true) {
      _saveNewSafetyPin(selectedCategory, descController.text, latLng);
    }
  }

  Future<void> _saveNewSafetyPin(String category, String description, LatLng latLng) async {
    final appState = context.read<AppBloc>().state;
    if (appState is AppReady) {
      final pin = SafetyPin(
        id: const Uuid().v4(),
        userId: appState.userId,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        category: category,
        description: description,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final storage = context.read<LocalStorageService>();
      await storage.saveSafetyPin(pin.toJson());

      setState(() {
        _safetyPins.add(pin);
        _addSafetyPinMode = false;
      });
      _updateMarkers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Safety Report Submitted (Offline)')),
        );
      }
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
              initialValue: selectedType,
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

  Future<void> _toggleTracking() async {
    if (_activeRoute != null) {
      await _trackingService?.stopTracking();
    } else {
      final appState = context.read<AppBloc>().state;
      if (appState is AppReady) {
        await _trackingService?.startTracking(userId: appState.userId);
      }
    }
  }

  void _drawRoute() {
    if (_activeRoute == null || _activeRoute!.points.isEmpty) return;

    final List<LatLng> latLngs = _activeRoute!.points.map((p) => p.toLatLng()).toList();
    
    _mapController?.addLine(
      LineOptions(
        geometry: latLngs,
        lineColor: "#FF5252",
        lineWidth: 4.0,
        lineOpacity: 0.8,
      ),
    );
  }

  Future<void> _toggleTopoMode() async {
    setState(() {
      _isTopoMode = !_isTopoMode;
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    final q = query.toLowerCase();
    LatLng? target;

    if (q.contains('delhi')) {
      target = const LatLng(28.6139, 77.2090);
    } else if (q.contains('london')) target = const LatLng(51.5074, -0.1278);
    else if (q.contains('new york')) target = const LatLng(40.7128, -74.0060);
    else if (q.contains('los angeles')) target = const LatLng(34.0522, -118.2437);
    else if (q.contains('tokyo')) target = const LatLng(35.6762, 139.6503);
    else if (q.contains('patna')) target = const LatLng(25.5941, 85.1376);

    if (target != null) {
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)));
      _mapController?.addSymbol(SymbolOptions(
        geometry: target,
        iconImage: 'custom-marker', // Assuming marker is handled or using default
        textField: query,
        textOffset: const Offset(0, 2),
      ));
    } else {
      try {
        List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          final latLng = LatLng(loc.latitude, loc.longitude);
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15)),
          );
          // Removed the addSymbol call for marker-15 since it doesn't exist in offline style
          _mapController?.addCircle(
            CircleOptions(
              geometry: latLng,
              circleRadius: 8.0,
              circleColor: '#2196F3',
              circleOpacity: 1.0,
              circleStrokeWidth: 2.0,
              circleStrokeColor: '#ffffff',
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Offline search is limited. You need internet to search for exact addresses like "$query".'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    }
  }

  void _downloadCurrentArea() async {
    final center = await _mapController?.cameraPosition?.target;
    if (center == null) return;

    // Simulate finding the region name
    String regionName = "Local Region (${center.latitude.toStringAsFixed(2)}, ${center.longitude.toStringAsFixed(2)})";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(center.latitude, center.longitude);
      if (placemarks.isNotEmpty) {
        regionName = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? regionName;
      }
    } catch (_) {}

    setState(() {
      _regions.insert(0, {
        'name': regionName,
        'size': '25 MB',
        'status': 'downloading',
        'progress': 0.0,
      });
      _showDownloads = true;
    });

    _startDownloadShim(0);
    _savePersistedRegions();
  }

  void _startDownloadShim(int index) async {
    if (_regions[index]['status'] == 'downloaded') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region already available offline.')),
      );
      return;
    }

    setState(() {
      _regions[index]['status'] = 'downloading';
      _regions[index]['progress'] = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _regions[index]['progress'] = i / 10.0;
      });
    }

    setState(() {
      _regions[index]['status'] = 'downloaded';
    });
    
    _savePersistedRegions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Succesfully downloaded ${_regions[index]['name']}!')),
      );
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
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
          initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 4.0), // Center of India
          styleString: "assets/maps/style_google.json",
          myLocationEnabled: _locationPermissionGranted,
          trackCameraPosition: true,
        ),
        // Topo mode: brown/earth tint overlay to simulate topographic view
        if (_isTopoMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0x33795548), // brown with 20% opacity
              ),
            ),
          ),
        if (_isTopoMode && !_showDownloads)
          Positioned(
            top: 80, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.brown[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🗻 TOPO MODE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
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
              color: Colors.grey[900],
              child: Column(
                children: [
                   AppBar(
                    backgroundColor: Colors.grey[850],
                    title: const Text('Offline Regions', style: TextStyle(color: Colors.white)),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _showDownloads = false),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: _downloadCurrentArea,
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('Download Current View Offline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _regions.length,
                      itemBuilder: (context, index) {
                        final region = _regions[index];
                        final isDownloading = region['status'] == 'downloading';
                        
                        return ListTile(
                          title: Text(region['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(region['size'], style: const TextStyle(color: Colors.grey)),
                              if (isDownloading)
                                LinearProgressIndicator(
                                  value: region['progress'],
                                  backgroundColor: Colors.grey[800],
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                          onTap: isDownloading ? null : () => _startDownloadShim(index),
                          trailing: region['status'] == 'downloaded' 
                              ? const Icon(Icons.check_circle, color: Colors.green) 
                              : isDownloading 
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download, color: Colors.blue),
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
            bottom: 110, right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _goToMyLocation,
                  mini: true,
                  heroTag: 'maps_loc_fab_fix',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: () => setState(() => _showDownloads = true),
                  mini: true,
                  backgroundColor: Colors.white,
                  heroTag: 'maps_download_trigger',
                  child: const Icon(Icons.download_for_offline, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: () => context.push('/ar-compass'),
                  mini: true,
                  backgroundColor: AppTheme.accentBlue,
                  heroTag: 'maps_ar_fab',
                  child: const Icon(Icons.view_in_ar, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _toggleTopoMode,
                  mini: true,
                  backgroundColor: _isTopoMode ? Colors.brown : Colors.blueGrey,
                  heroTag: 'maps_topo_fab',
                  child: Icon(_isTopoMode ? Icons.terrain : Icons.map_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _toggleTracking,
                  mini: true,
                  backgroundColor: _activeRoute != null ? Colors.red : Colors.blue,
                  heroTag: 'maps_track_fab',
                  child: Icon(_activeRoute != null ? Icons.stop : Icons.route),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: () => setState(() {
                    _addSafetyPinMode = !_addSafetyPinMode;
                    _addPinMode = false;
                  }),
                  mini: true,
                  backgroundColor: _addSafetyPinMode ? Colors.red : Colors.redAccent,
                  heroTag: 'maps_safety_report_fab',
                  child: Icon(_addSafetyPinMode ? Icons.close : Icons.warning_amber),
                ),
              ],
            ),
          ),
        if (_addPinMode || _addSafetyPinMode)
          Positioned(
            top: 100, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _addSafetyPinMode 
                      ? 'Tap on map to report a safety hazard' 
                      : 'Tap on map to add a survival point',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        if (_activeRoute != null)
          Positioned(
            top: 140, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Recording Route: ${_activeRoute!.distanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
