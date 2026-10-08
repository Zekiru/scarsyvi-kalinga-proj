// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_flow_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonFlowModelAdapter extends TypeAdapter<LessonFlowModel> {
  @override
  final int typeId = 5;

  @override
  LessonFlowModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonFlowModel(
      lfId: fields[0] as int?,
      timeMinutes: fields[1] as int,
      stage: fields[2] as String,
      description: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LessonFlowModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.lfId)
      ..writeByte(1)
      ..write(obj.timeMinutes)
      ..writeByte(2)
      ..write(obj.stage)
      ..writeByte(3)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonFlowModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
