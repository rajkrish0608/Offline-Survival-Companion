import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadPois();
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
    final pois = await storage.getPOIs(user);
    if (mounted) {
      setState(() {
        _pois = pois.map((p) => POI.fromJson(p)).toList();
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
          // Camera Preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          
          // AR HUD Overlay
          Positioned.fill(child: _buildHUD()),
          
          // Top Controls
          Positioned(
            top: 40, left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Stack(
      children: [
        // Compass Strip
        Positioned(
          top: 60, left: 0, right: 0,
          child: _buildCompassStrip(),
        ),
        
        // POI Markers
        ..._pois.map((poi) => _buildPOIMarker(poi)),
        
        // Center Reticle
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
          // Cardinal Directions
          _buildDirectionLabel("N", 0),
          _buildDirectionLabel("NE", 45),
          _buildDirectionLabel("E", 90),
          _buildDirectionLabel("SE", 135),
          _buildDirectionLabel("S", 180),
          _buildDirectionLabel("SW", 225),
          _buildDirectionLabel("W", 270),
          _buildDirectionLabel("NW", 315),
          
          // Current Heading Indicator
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
    
    // Only show if within field of view (approx 60 deg)
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
    // This is a simplified AR marker based on bearing
    // In a real app, we'd calculate azimuth based on current location
    // Since we don't have current location here yet, we'll mock it or
    // just show them at fixed bearings for now to demonstrate the HUD.
    
    // TODO: Calculate real bearing from current location to POI
    double mockBearing = (poi.latitude * 100) % 360; // Mock bearing
    
    double relativeAngle = (mockBearing - (_direction ?? 0)) % 360;
    if (relativeAngle > 180) relativeAngle -= 360;
    if (relativeAngle < -180) relativeAngle += 360;
    
    if (relativeAngle.abs() > 30) return const SizedBox();
    
    double screenWidth = MediaQuery.of(context).size.width;
    double xOffset = (relativeAngle / 30) * (screenWidth / 2);
    
    return Center(
      child: Transform.translate(
        offset: Offset(xOffset, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIconForType(poi.type), color: Colors.cyanAccent, size: 30),
            Text(
              poi.title,
              style: const TextStyle(color: Colors.white, fontSize: 12, backgroundColor: Colors.black45),
            ),
          ],
        ),
      ),
    );
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
