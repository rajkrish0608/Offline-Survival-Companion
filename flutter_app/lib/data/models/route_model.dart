import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

part 'route_model.g.dart';

@HiveType(typeId: 6)
class BreadcrumbPoint extends Equatable {
  @HiveField(0)
  final double latitude;
  
  @HiveField(1)
  final double longitude;
  
  @HiveField(2)
  final DateTime timestamp;

  const BreadcrumbPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [latitude, longitude, timestamp];

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
  };

  factory BreadcrumbPoint.fromJson(Map<String, dynamic> json) => BreadcrumbPoint(
    latitude: json['latitude'],
    longitude: json['longitude'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

@HiveType(typeId: 7)
class SurvivalRoute extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String userId;
  
  @HiveField(2)
  final String name;
  
  @HiveField(3)
  final List<BreadcrumbPoint> points;
  
  @HiveField(4)
  final DateTime startTime;
  
  @HiveField(5)
  final DateTime? endTime;
  
  @HiveField(6)
  final double distanceKm;

  const SurvivalRoute({
    required this.id,
    required this.userId,
    required this.name,
    required this.points,
    required this.startTime,
    this.endTime,
    this.distanceKm = 0.0,
  });

  @override
  List<Object?> get props => [id, userId, name, points, startTime, endTime, distanceKm];

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'points': points.map((p) => p.toJson()).toList(),
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'distance_km': distanceKm,
  };

  factory SurvivalRoute.fromJson(Map<String, dynamic> json) => SurvivalRoute(
    id: json['id'],
    userId: json['user_id'],
    name: json['name'],
    points: (json['points'] as List).map((p) => BreadcrumbPoint.fromJson(p)).toList(),
    startTime: DateTime.parse(json['start_time']),
    endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
    distanceKm: json['distance_km'] ?? 0.0,
  );
}
