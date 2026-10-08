// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentAttendanceRecordAdapter
    extends TypeAdapter<StudentAttendanceRecord> {
  @override
  final int typeId = 0;

  @override
  StudentAttendanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentAttendanceRecord(
      studentId: fields[0] as int,
      status: fields[1] as String,
      notes: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StudentAttendanceRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAttendanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttendanceSessionModelAdapter
    extends TypeAdapter<AttendanceSessionModel> {
  @override
  final int typeId = 1;

  @override
  AttendanceSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceSessionModel(
      id: fields[0] as int?,
      date: fields[1] as String,
      remarks: fields[2] as String?,
      records: (fields[3] as List).cast<StudentAttendanceRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceSessionModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.remarks)
      ..writeByte(3)
      ..write(obj.records);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
