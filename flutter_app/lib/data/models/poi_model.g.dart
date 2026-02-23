// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poi_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class POIAdapter extends TypeAdapter<POI> {
  @override
  final int typeId = 5;

  @override
  POI read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return POI(
      id: fields[0] as String,
      user_id: fields[1] as String,
      title: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      type: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, POI obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.user_id)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is POIAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
