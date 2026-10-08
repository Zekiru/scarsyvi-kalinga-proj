// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GradeLevelModelAdapter extends TypeAdapter<GradeLevelModel> {
  @override
  final int typeId = 2;

  @override
  GradeLevelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GradeLevelModel(
      glId: fields[0] as int,
      gradeLevelName: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GradeLevelModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.glId)
      ..writeByte(1)
      ..write(obj.gradeLevelName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeLevelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LessonPlanSummaryModelAdapter
    extends TypeAdapter<LessonPlanSummaryModel> {
  @override
  final int typeId = 3;

  @override
  LessonPlanSummaryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonPlanSummaryModel(
      lpId: fields[0] as int,
      lpTitle: fields[1] as String,
      learningArea: fields[2] as String,
      primaryLanguage: fields[3] as String,
      suggestedDemographic: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LessonPlanSummaryModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.lpId)
      ..writeByte(1)
      ..write(obj.lpTitle)
      ..writeByte(2)
      ..write(obj.learningArea)
      ..writeByte(3)
      ..write(obj.primaryLanguage)
      ..writeByte(4)
      ..write(obj.suggestedDemographic);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonPlanSummaryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClassroomModelAdapter extends TypeAdapter<ClassroomModel> {
  @override
  final int typeId = 4;

  @override
  ClassroomModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassroomModel(
      classroomId: fields[0] as int?,
      name: fields[1] as String,
      schoolName: fields[2] as String,
      section: fields[3] as String?,
      schoolYear: fields[4] as String,
      isActive: fields[5] as bool,
      adviser: fields[6] as int?,
      students: (fields[7] as List).cast<StudentModel>(),
      gradeLevels: (fields[8] as List).cast<GradeLevelModel>(),
      lessonPlan: fields[9] as LessonPlanSummaryModel?,
      gradeLevelIds: (fields[10] as List).cast<int>(),
      lessonPlanId: fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassroomModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.classroomId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.schoolName)
      ..writeByte(3)
      ..write(obj.section)
      ..writeByte(4)
      ..write(obj.schoolYear)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.adviser)
      ..writeByte(7)
      ..write(obj.students)
      ..writeByte(8)
      ..write(obj.gradeLevels)
      ..writeByte(9)
      ..write(obj.lessonPlan)
      ..writeByte(10)
      ..write(obj.gradeLevelIds)
      ..writeByte(11)
      ..write(obj.lessonPlanId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassroomModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
