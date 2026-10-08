import 'package:hive/hive.dart';

part 'student_model.g.dart';

@HiveType(typeId: 14)
enum StudentSortBy {
  @HiveField(0)
  nameAsc,
  @HiveField(1)
  nameDesc,
  @HiveField(2)
  gradeAvgDesc,
  @HiveField(3)
  attendanceRateDesc,
}

@HiveType(typeId: 15)
class StudentModel extends HiveObject {
  @HiveField(0)
  final int? studentId;

  @HiveField(1)
  final int glId;

  @HiveField(2)
  final String firstName;

  @HiveField(3)
  final String lastName;

  @HiveField(4)
  final String gender;

  @HiveField(5)
  final String? lrn;

  @HiveField(6)
  final double attendanceRate;

  @HiveField(7)
  final double gradeAvg;

  StudentModel({
    this.studentId,
    required this.glId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.lrn,
    this.attendanceRate = 0.0,
    this.gradeAvg = 0.0,
  });

  String get fullName => '$firstName $lastName';
  String get sortableName => '$lastName, $firstName';

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json['student_id'] as int?,
      glId: json['gl_id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      lrn: json['lrn'] as String?,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      gradeAvg: (json['grade_avg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (studentId != null) 'student_id': studentId,
      'gl_id': glId,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      if (lrn != null) 'lrn': lrn,
      'attendance_rate': attendanceRate,
      'grade_avg': gradeAvg,
    };
  }

  int compareTo(StudentModel other, StudentSortBy sortBy) {
    switch (sortBy) {
      case StudentSortBy.nameAsc:
        return sortableName.toLowerCase().compareTo(other.sortableName.toLowerCase());
      case StudentSortBy.nameDesc:
        return other.sortableName.toLowerCase().compareTo(sortableName.toLowerCase());
      case StudentSortBy.gradeAvgDesc:
        return other.gradeAvg.compareTo(gradeAvg);
      case StudentSortBy.attendanceRateDesc:
        return other.attendanceRate.compareTo(attendanceRate);
    }
  }
}
