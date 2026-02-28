import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/data/models/poi_model.dart';
import 'package:provider/provider.dart';

class ARCompassScreen extends StatefulWidget {
  const ARCompassScreen({super.key});

  @override
  State<ARCompassScreen> createState() => _ARCompassScreenState();
}

class _ARCompassScreenState extends State<ARCompassScreen> {
  CameraController? _cameraController;
  List<POI> _pois = [];
  double? _direction;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadPois();
    _startPositionUpdates();
    
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _direction = event.heading;
        });
      }
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _loadPois() async {
    final storage = context.read<LocalStorageService>();
    final user = await storage.getOrCreateDefaultUser();
    final pois = await storage.getPOIs(user['id']);
    if (mounted) {
      setState(() {
        _pois = pois.map((p) => POI.fromJson(p)).toList();
      });
    }
  }

  void _startPositionUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          Positioned.fill(child: _buildHUD()),
          Positioned(
            top: 40, left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_currentPosition == null)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Acquiring GPS Signal...', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Stack(
      children: [
        Positioned(
          top: 60, left: 0, right: 0,
          child: _buildCompassStrip(),
        ),
        ..._pois.map((poi) => _buildPOIMarker(poi)),
        Center(
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompassStrip() {
    if (_direction == null) return const SizedBox();
    return Container(
      height: 60,
      color: Colors.black26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildDirectionLabel("N", 0),
          _buildDirectionLabel("NE", 45),
          _buildDirectionLabel("E", 90),
          _buildDirectionLabel("SE", 135),
          _buildDirectionLabel("S", 180),
          _buildDirectionLabel("SW", 225),
          _buildDirectionLabel("W", 270),
          _buildDirectionLabel("NW", 315),
          const Positioned(
            top: 0,
            child: Icon(Icons.arrow_drop_down, color: Colors.red, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionLabel(String text, double angle) {
    double relativeAngle = (angle - (_direction ?? 0)) % 360;
    if (relativeAngle > 180) relativeAngle -= 360;
    if (relativeAngle < -180) relativeAngle += 360;
    if (relativeAngle.abs() > 45) return const SizedBox();
    double xOffset = (relativeAngle / 45) * (MediaQuery.of(context).size.width / 2);
    return Transform.translate(
      offset: Offset(xOffset, 0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _buildPOIMarker(POI poi) {
    if (_currentPosition == null || _direction == null) return const SizedBox();

    final bearing = _calculateBearing(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      poi.latitude,
      poi.longitude,
    );
    
    double relativeAngle = (bearing - (_direction ?? 0)) % 360;
    if (relativeAngle > 180) relativeAngle -= 360;
    if (relativeAngle < -180) relativeAngle += 360;
    
    if (relativeAngle.abs() > 30) return const SizedBox();
    
    double screenWidth = MediaQuery.of(context).size.width;
    double xOffset = (relativeAngle / 30) * (screenWidth / 2);
    
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      poi.latitude,
      poi.longitude,
    );

    return Center(
      child: Transform.translate(
        offset: Offset(xOffset, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIconForType(poi.type), color: Colors.cyanAccent, size: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
              child: Column(
                children: [
                  Text(poi.title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('${(distance / 1000).toStringAsFixed(1)}km', style: const TextStyle(color: Colors.cyanAccent, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double lat1Rad = lat1 * math.pi / 180;
    double lat2Rad = lat2 * math.pi / 180;
    double dLon = (lon2 - lon1) * math.pi / 180;

    double y = math.sin(dLon) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
               math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'water': return Icons.water_drop;
      case 'shelter': return Icons.home;
      case 'hazard': return Icons.warning;
      default: return Icons.location_on;
    }
  }
}
