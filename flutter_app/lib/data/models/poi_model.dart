import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'poi_model.g.dart';

@HiveType(typeId: 5)
class POI extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String user_id;
  
  @HiveField(2)
  final String title;
  
  @HiveField(3)
  final double latitude;
  
  @HiveField(4)
  final double longitude;
  
  @HiveField(5)
  final String type; // 'water', 'shelter', 'hazard', 'other'
  
  @HiveField(6)
  final DateTime createdAt;

  const POI({
    required this.id,
    required this.user_id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, user_id, title, latitude, longitude, type, createdAt];

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': user_id,
    'title': title,
    'latitude': latitude,
    'longitude': longitude,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
  };

  factory POI.fromJson(Map<String, dynamic> json) => POI(
    id: json['id'],
    user_id: json['user_id'],
    title: json['title'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    type: json['type'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
