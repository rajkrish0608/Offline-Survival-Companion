// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safety_pin_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SafetyPinAdapter extends TypeAdapter<SafetyPin> {
  @override
  final int typeId = 7;

  @override
  SafetyPin read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SafetyPin(
      id: fields[0] as String,
      userId: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      category: fields[4] as String,
      description: fields[5] as String,
      isSynced: fields[6] as bool,
      createdAt: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SafetyPin obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.isSynced)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyPinAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SafetyPin _$SafetyPinFromJson(Map<String, dynamic> json) => SafetyPin(
      id: json['id'] as String,
      userId: json['userId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      isSynced: json['isSynced'] as bool? ?? false,
      createdAt: (json['createdAt'] as num).toInt(),
    );

Map<String, dynamic> _$SafetyPinToJson(SafetyPin instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'category': instance.category,
      'description': instance.description,
      'isSynced': instance.isSynced,
      'createdAt': instance.createdAt,
    };
