// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_grade_level_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonGradeLevelModelAdapter extends TypeAdapter<LessonGradeLevelModel> {
  @override
  final int typeId = 6;

  @override
  LessonGradeLevelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonGradeLevelModel(
      glId: fields[0] as int,
      gradeLevelName: fields[1] as String?,
      iContentStandard: fields[2] as String?,
      iPerformanceStandard: fields[3] as String?,
      iCompetenciesCodes: fields[4] as String?,
      iObjectives: fields[5] as String?,
      lContext: fields[6] as String?,
      wReflectionQuestions: fields[7] as String?,
      reRemediation: fields[8] as String?,
      reEnrichment: fields[9] as String?,
      flows: (fields[10] as List).cast<LessonFlowModel>(),
      gradingTasks: (fields[11] as List).cast<LessonGradingModel>(),
      materialsDetail: (fields[12] as List).cast<LessonGradeMaterialModel>(),
      materialIds: (fields[13] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, LessonGradeLevelModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.glId)
      ..writeByte(1)
      ..write(obj.gradeLevelName)
      ..writeByte(2)
      ..write(obj.iContentStandard)
      ..writeByte(3)
      ..write(obj.iPerformanceStandard)
      ..writeByte(4)
      ..write(obj.iCompetenciesCodes)
      ..writeByte(5)
      ..write(obj.iObjectives)
      ..writeByte(6)
      ..write(obj.lContext)
      ..writeByte(7)
      ..write(obj.wReflectionQuestions)
      ..writeByte(8)
      ..write(obj.reRemediation)
      ..writeByte(9)
      ..write(obj.reEnrichment)
      ..writeByte(10)
      ..write(obj.flows)
      ..writeByte(11)
      ..write(obj.gradingTasks)
      ..writeByte(12)
      ..write(obj.materialsDetail)
      ..writeByte(13)
      ..write(obj.materialIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonGradeLevelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
