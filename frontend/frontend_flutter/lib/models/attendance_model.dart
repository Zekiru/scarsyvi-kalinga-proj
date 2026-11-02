import 'package:hive/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 0)
class StudentAttendanceRecord extends HiveObject {
  @HiveField(0)
  final int studentId;

  @HiveField(1)
  final String status;

  @HiveField(2)
  final String? notes;

  StudentAttendanceRecord({
    required this.studentId,
    this.status = 'PRESENT',
    this.notes,
  });

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceRecord(
      studentId: json['student_id'] as int,
      status: json['status'] as String? ?? 'PRESENT',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

@HiveType(typeId: 1)
class AttendanceSessionModel extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String date; // YYYY-MM-DD

  @HiveField(2)
  final String? remarks;

  @HiveField(3)
  final List<StudentAttendanceRecord> records;

  /// Which classroom this session belongs to. Added after the first release:
  /// sessions saved by older versions load with null.
  @HiveField(4)
  final int? classroomId;

  AttendanceSessionModel({
    this.id,
    required this.date,
    this.remarks,
    required this.records,
    this.classroomId,
  });

  /// Formats a date as YYYY-MM-DD using the device's LOCAL time, so a teacher
  /// in Manila taking attendance at 7 AM doesn't get yesterday's date.
  static String formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      id: json['id'] as int?,
      date: json['date'] as String,
      remarks: json['remarks'] as String?,
      records: (json['records'] as List<dynamic>?)
              ?.map((item) => StudentAttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      classroomId: json['classroom_id'] as int?,
    );
  }

  /// Body sent to the server. classroomId is not included: it is already in
  /// the URL (/classrooms/{id}/attendance/).
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'remarks': remarks ?? '',
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}
