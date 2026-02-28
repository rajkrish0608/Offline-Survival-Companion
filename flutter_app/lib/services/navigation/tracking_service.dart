import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:offline_survival_companion/data/models/route_model.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class TrackingService {
  final LocalStorageService _storageService;
  final Logger _logger = Logger();
  
  StreamSubscription<Position>? _positionSubscription;
  String? _activeRouteId;
  String? _activeUserId;
  List<BreadcrumbPoint> _currentPoints = [];
  double _totalDistance = 0.0;
  Position? _lastPosition;

  final StreamController<SurvivalRoute?> _activeRouteController = StreamController<SurvivalRoute?>.broadcast();
  Stream<SurvivalRoute?> get activeRouteStream => _activeRouteController.stream;

  TrackingService(this._storageService);

  bool get isTracking => _activeRouteId != null;

  Future<void> startTracking({required String userId, String? routeName}) async {
    if (isTracking) return;

    try {
      final hasPermission = await _handlePermission();
      if (!hasPermission) {
        _logger.e('Location permission denied');
        return;
      }

      _activeUserId = userId;
      _activeRouteId = Uuid().v4();
      final startTime = DateTime.now();
      _currentPoints = [];
      _totalDistance = 0.0;
      _lastPosition = null;

      final route = SurvivalRoute(
        id: _activeRouteId!,
        userId: userId,
        name: routeName ?? 'Route ${startTime.toIso8601String()}',
        points: [],
        startTime: startTime,
      );

      await _storageService.saveRoute({
        'id': route.id,
        'user_id': route.userId,
        'name': route.name,
        'start_time': route.startTime.millisecondsSinceEpoch,
        'distance_km': 0.0,
      });

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10 meters
        ),
      ).listen(_onPositionUpdate);

      _activeRouteController.add(route);
      _logger.i('Started tracking route: $_activeRouteId');
    } catch (e) {
      _logger.e('Failed to start tracking: $e');
      _activeRouteId = null;
    }
  }

  void _onPositionUpdate(Position position) {
    if (_activeRouteId == null) return;

    final point = BreadcrumbPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
    );

    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance / 1000.0; // Convert to km
    }
    _lastPosition = position;
    _currentPoints.add(point);

    // Save point to DB
    _storageService.addBreadcrumbPoint({
      'route_id': _activeRouteId!,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'timestamp': point.timestamp.millisecondsSinceEpoch,
    });

    // Update route metadata periodically if needed, or just keep it in memory
    _activeRouteController.add(SurvivalRoute(
      id: _activeRouteId!,
      userId: _activeUserId!,
      name: 'Active Route',
      points: List.from(_currentPoints),
      startTime: DateTime.now(), // Simplified for stream
      distanceKm: _totalDistance,
    ));
  }

  Future<void> stopTracking() async {
    if (!isTracking) return;

    try {
      await _positionSubscription?.cancel();
      
      final endTime = DateTime.now();
      await _storageService.updateRoute(_activeRouteId!, {
        'end_time': endTime.millisecondsSinceEpoch,
        'distance_km': _totalDistance,
      });

      _logger.i('Stopped tracking route: $_activeRouteId. Total distance: $_totalDistance km');
      
      _activeRouteId = null;
      _activeUserId = null;
      _activeRouteController.add(null);
    } catch (e) {
      _logger.e('Failed to stop tracking: $e');
    }
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<List<SurvivalRoute>> getSavedRoutes(String userId) async {
    final routesData = await _storageService.getRoutes(userId);
    List<SurvivalRoute> routes = [];
    
    for (var r in routesData) {
      final pointsData = await _storageService.getRoutePoints(r['id']);
      final points = pointsData.map((p) => BreadcrumbPoint(
        latitude: p['latitude'],
        longitude: p['longitude'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(p['timestamp']),
      )).toList();

      routes.add(SurvivalRoute(
        id: r['id'],
        userId: r['user_id'],
        name: r['name'],
        points: points,
        startTime: DateTime.fromMillisecondsSinceEpoch(r['start_time']),
        endTime: r['end_time'] != null ? DateTime.fromMillisecondsSinceEpoch(r['end_time']) : null,
        distanceKm: r['distance_km'] ?? 0.0,
      ));
    }
    return routes;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _activeRouteController.close();
  }
}
