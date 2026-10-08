// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_grading_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonGradingModelAdapter extends TypeAdapter<LessonGradingModel> {
  @override
  final int typeId = 8;

  @override
  LessonGradingModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonGradingModel(
      lgId: fields[0] as int?,
      taskName: fields[1] as String,
      taskDescription: fields[2] as String?,
      gradeWeight: fields[3] as double,
      maxScore: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LessonGradingModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.lgId)
      ..writeByte(1)
      ..write(obj.taskName)
      ..writeByte(2)
      ..write(obj.taskDescription)
      ..writeByte(3)
      ..write(obj.gradeWeight)
      ..writeByte(4)
      ..write(obj.maxScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonGradingModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
