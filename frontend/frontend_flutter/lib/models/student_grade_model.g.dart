// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_grade_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentGradeItemAdapter extends TypeAdapter<StudentGradeItem> {
  @override
  final int typeId = 11;

  @override
  StudentGradeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentGradeItem(
      studentId: fields[0] as int,
      gradingTaskId: fields[1] as int,
      score: fields[2] as double,
      feedback: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StudentGradeItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.gradingTaskId)
      ..writeByte(2)
      ..write(obj.score)
      ..writeByte(3)
      ..write(obj.feedback);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentGradeBatchPayloadAdapter
    extends TypeAdapter<StudentGradeBatchPayload> {
  @override
  final int typeId = 12;

  @override
  StudentGradeBatchPayload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentGradeBatchPayload(
      grades: (fields[0] as List).cast<StudentGradeItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, StudentGradeBatchPayload obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.grades);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradeBatchPayloadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentGradeReadModelAdapter extends TypeAdapter<StudentGradeReadModel> {
  @override
  final int typeId = 13;

  @override
  StudentGradeReadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentGradeReadModel(
      id: fields[0] as int,
      studentId: fields[1] as int,
      studentName: fields[2] as String?,
      gradingTaskId: fields[3] as int,
      gradingTaskTitle: fields[4] as String?,
      score: fields[5] as double,
      feedback: fields[6] as String?,
      submittedAt: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StudentGradeReadModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.studentName)
      ..writeByte(3)
      ..write(obj.gradingTaskId)
      ..writeByte(4)
      ..write(obj.gradingTaskTitle)
      ..writeByte(5)
      ..write(obj.score)
      ..writeByte(6)
      ..write(obj.feedback)
      ..writeByte(7)
      ..write(obj.submittedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentGradeReadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
