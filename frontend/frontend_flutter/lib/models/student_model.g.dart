// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentModelAdapter extends TypeAdapter<StudentModel> {
  @override
  final int typeId = 15;

  @override
  StudentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentModel(
      studentId: fields[0] as int?,
      glId: fields[1] as int,
      firstName: fields[2] as String,
      lastName: fields[3] as String,
      gender: fields[4] as String,
      lrn: fields[5] as String?,
      attendanceRate: fields[6] as double,
      gradeAvg: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, StudentModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.glId)
      ..writeByte(2)
      ..write(obj.firstName)
      ..writeByte(3)
      ..write(obj.lastName)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.lrn)
      ..writeByte(6)
      ..write(obj.attendanceRate)
      ..writeByte(7)
      ..write(obj.gradeAvg);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentSortByAdapter extends TypeAdapter<StudentSortBy> {
  @override
  final int typeId = 14;

  @override
  StudentSortBy read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StudentSortBy.nameAsc;
      case 1:
        return StudentSortBy.nameDesc;
      case 2:
        return StudentSortBy.gradeAvgDesc;
      case 3:
        return StudentSortBy.attendanceRateDesc;
      default:
        return StudentSortBy.nameAsc;
    }
  }

  @override
  void write(BinaryWriter writer, StudentSortBy obj) {
    switch (obj) {
      case StudentSortBy.nameAsc:
        writer.writeByte(0);
        break;
      case StudentSortBy.nameDesc:
        writer.writeByte(1);
        break;
      case StudentSortBy.gradeAvgDesc:
        writer.writeByte(2);
        break;
      case StudentSortBy.attendanceRateDesc:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentSortByAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
