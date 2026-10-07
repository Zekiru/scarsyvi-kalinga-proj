enum StudentSortBy { nameAsc, nameDesc, gradeAvgDesc, attendanceRateDesc }

class StudentModel {
  final int? studentId;
  final int glId;
  final String firstName;
  final String lastName;
  final String gender;
  final String? lrn;
  final double attendanceRate;
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

  /// Comparison helper for sorting student lists
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
