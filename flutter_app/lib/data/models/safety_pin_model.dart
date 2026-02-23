import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'safety_pin_model.g.dart';

@JsonSerializable()
@HiveType(typeId: 7)
class SafetyPin extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String userId;
  
  @HiveField(2)
  final double latitude;
  
  @HiveField(3)
  final double longitude;
  
  @HiveField(4)
  final String category; // 'hazard', 'lighting', 'shelter', 'safe-haven'
  
  @HiveField(5)
  final String description;
  
  @HiveField(6)
  final bool isSynced;
  
  @HiveField(7)
  final int createdAt;

  const SafetyPin({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    this.isSynced = false,
    required this.createdAt,
  });

  factory SafetyPin.fromJson(Map<String, dynamic> json) => _$SafetyPinFromJson(json);
  Map<String, dynamic> toJson() => _$SafetyPinToJson(this);

  SafetyPin copyWith({bool? isSynced}) {
    return SafetyPin(
      id: id,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      category: category,
      description: description,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, latitude, longitude, category, description, isSynced, createdAt];
}
