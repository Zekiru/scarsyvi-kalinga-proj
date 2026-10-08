// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_grade_material_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LessonGradeMaterialModelAdapter
    extends TypeAdapter<LessonGradeMaterialModel> {
  @override
  final int typeId = 7;

  @override
  LessonGradeMaterialModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonGradeMaterialModel(
      material: fields[0] as MaterialModel,
      usageInstructions: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LessonGradeMaterialModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.material)
      ..writeByte(1)
      ..write(obj.usageInstructions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonGradeMaterialModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
