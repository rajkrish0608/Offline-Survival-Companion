// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BreadcrumbPointAdapter extends TypeAdapter<BreadcrumbPoint> {
  @override
  final int typeId = 6;

  @override
  BreadcrumbPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BreadcrumbPoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BreadcrumbPoint obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreadcrumbPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SurvivalRouteAdapter extends TypeAdapter<SurvivalRoute> {
  @override
  final int typeId = 7;

  @override
  SurvivalRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SurvivalRoute(
      id: fields[0] as String,
      userId: fields[1] as String,
      name: fields[2] as String,
      points: (fields[3] as List).cast<BreadcrumbPoint>(),
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime?,
      distanceKm: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SurvivalRoute obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.points)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.distanceKm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurvivalRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
