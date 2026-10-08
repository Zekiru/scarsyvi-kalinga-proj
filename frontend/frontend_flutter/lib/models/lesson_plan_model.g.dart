// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonPlanModelAdapter extends TypeAdapter<LessonPlanModel> {
  @override
  final int typeId = 9;

  @override
  LessonPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonPlanModel(
      lpId: fields[0] as int?,
      lpTitle: fields[1] as String,
      learningArea: fields[2] as String,
      primaryLanguage: fields[3] as String,
      suggestedDemographic: fields[4] as String?,
      learningModelDescription: fields[5] as String?,
      intentionsDescription: fields[6] as String?,
      notes: fields[7] as String?,
      gradeLevels: (fields[8] as List).cast<LessonGradeLevelModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, LessonPlanModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.lpId)
      ..writeByte(1)
      ..write(obj.lpTitle)
      ..writeByte(2)
      ..write(obj.learningArea)
      ..writeByte(3)
      ..write(obj.primaryLanguage)
      ..writeByte(4)
      ..write(obj.suggestedDemographic)
      ..writeByte(5)
      ..write(obj.learningModelDescription)
      ..writeByte(6)
      ..write(obj.intentionsDescription)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.gradeLevels);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
