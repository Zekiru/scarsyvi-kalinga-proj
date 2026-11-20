import 'dart:convert';

enum AttendanceStatus {
  present('PRESENT', 'Present'),
  late('LATE', 'Late'),
  absent('ABSENT', 'Absent'),
  excused('EXCUSED', 'Excused');

  const AttendanceStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AttendanceStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'LATE':
        return AttendanceStatus.late;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'EXCUSED':
        return AttendanceStatus.excused;
      case 'PRESENT':
      default:
        return AttendanceStatus.present;
    }
  }
}

class Student {
  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender = '',
    this.lrn = '',
    this.gradeLevelId,
    this.gradeLevelName = '',
    this.gradeAverage,
    this.attendanceAverage,
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_stu_*`
  final String firstName;
  final String lastName;
  final String gender; // 'M', 'F', or ''
  final String lrn;
  final int? gradeLevelId;
  final String gradeLevelName;
  final double? gradeAverage; // Computed by selectors.py (0-100)[cite: 1]
  final double? attendanceAverage; // Computed by selectors.py (0-100)[cite: 1]
  final bool isPendingSync;

  String get fullName => '$firstName $lastName'.trim();
  String get formalName =>
      lastName.isNotEmpty ? '$lastName, $firstName' : firstName;

  factory Student.fromJson(Map<String, dynamic> json) {
    final glObj = json['grade_level_detail'] ?? json['grade_level'];
    int? glId;
    String glName = (json['grade_level_name'] ?? '') as String;

    if (glObj is int) {
      glId = glObj;
    } else if (glObj is Map<String, dynamic>) {
      glId = (glObj['id'] ?? glObj['grade_level_id']) as int?;
      glName = (glObj['name'] ?? glObj['grade_name'] ?? glName) as String;
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return Student(
      id: (json['student_id'] ?? json['id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      gender: (json['gender'] ?? '') as String,
      lrn: (json['lrn'] ?? '') as String,
      gradeLevelId: glId,
      gradeLevelName: glName,
      gradeAverage: parseNullableDouble(json['grade_average']),
      attendanceAverage: parseNullableDouble(json['attendance_average']),
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender,
        'lrn': lrn,
        'grade_level': gradeLevelId,
        'grade_level_name': gradeLevelName,
        'grade_average': gradeAverage,
        'attendance_average': attendanceAverage,
        'is_pending_sync': isPendingSync,
      };
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.studentId,
    this.studentName = '',
    required this.status,
    this.notes = '',
  });

  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final String notes;

  factory StudentAttendanceEntry.fromJson(Map<String, dynamic> json) {
    final stuObj = json['student_detail'] ?? json['student'];
    String sId = '';
    String sName = (json['student_name'] ?? '') as String;

    if (stuObj is Map<String, dynamic>) {
      sId = (stuObj['student_id'] ?? stuObj['id'] ?? '').toString();
      final fn = (stuObj['first_name'] ?? '') as String;
      final ln = (stuObj['last_name'] ?? '') as String;
      if (sName.isEmpty) sName = '$fn $ln'.trim();
    } else if (stuObj != null) {
      sId = stuObj.toString();
    }

    return StudentAttendanceEntry(
      studentId: sId,
      studentName: sName,
      status: AttendanceStatus.fromString(json['status'] as String?),
      notes: (json['notes'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'student': studentId,
        'student_name': studentName,
        'status': status.apiValue,
        'notes': notes,
      };
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classroomId,
    required this.date,
    this.remarks = '',
    this.records = const [],
    this.isPendingSync = false,
  });

  final String id;
  final String classroomId;
  final String date; // YYYY-MM-DD[cite: 1]
  final String remarks;
  final List<StudentAttendanceEntry> records;
  final bool isPendingSync;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final parsedRecords = <StudentAttendanceEntry>[];
    final rawRecs = json['records'] ?? json['attendances'];
    if (rawRecs is List) {
      for (final item in rawRecs) {
        if (item is Map<String, dynamic>) {
          parsedRecords.add(StudentAttendanceEntry.fromJson(item));
        }
      }
    }

    return AttendanceSession(
      id: (json['session_id'] ?? json['id'] ?? '').toString(),
      classroomId: (json['classroom'] ?? '').toString(),
      date: (json['date'] ?? '') as String,
      remarks: (json['remarks'] ?? '') as String,
      records: parsedRecords,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'classroom': classroomId,
        'date': date,
        'remarks': remarks,
        'records': records.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };
}

class StudentGrade {
  const StudentGrade({
    required this.id,
    required this.studentId,
    this.studentName = '',
    required this.gradingTaskId,
    this.gradingTaskName = '',
    required this.score,
    this.maxScore = 100.0,
    this.feedback = '',
    this.isPendingSync = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String gradingTaskId; // PK or `temp_*` of curriculum.LessonGrading[cite: 1]
  final String gradingTaskName;
  final double score;
  final double maxScore;
  final String feedback;
  final bool isPendingSync;

  factory StudentGrade.fromJson(Map<String, dynamic> json) {
    final stuObj = json['student_detail'] ?? json['student'];
    String sId = '';
    String sName = (json['student_name'] ?? '') as String;

    if (stuObj is Map<String, dynamic>) {
      sId = (stuObj['student_id'] ?? stuObj['id'] ?? '').toString();
      final fn = (stuObj['first_name'] ?? '') as String;
      final ln = (stuObj['last_name'] ?? '') as String;
      if (sName.isEmpty) sName = '$fn $ln'.trim();
    } else if (stuObj != null) {
      sId = stuObj.toString();
    }

    final taskObj = json['grading_task_detail'] ?? json['grading_task'];
    String tId = '';
    String tName =
        (json['grading_task_name'] ?? json['criteria_name'] ?? '') as String;
    double maxVal = 100.0;

    if (taskObj is Map<String, dynamic>) {
      tId = (taskObj['lesson_grading_id'] ?? taskObj['id'] ?? '').toString();
      tName = (taskObj['criteria_name'] ?? taskObj['title'] ?? tName) as String;
      final rawMax = taskObj['max_score'] ?? taskObj['weight_percentage'];
      if (rawMax is num) maxVal = rawMax.toDouble();
    } else if (taskObj != null) {
      tId = taskObj.toString();
    }

    double toDouble(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString()) ?? fallback;
      return fallback;
    }

    return StudentGrade(
      id: (json['grade_id'] ?? json['id'] ?? '').toString(),
      studentId: sId,
      studentName: sName,
      gradingTaskId: tId,
      gradingTaskName: tName,
      score: toDouble(json['score'], 0.0),
      maxScore: toDouble(json['max_score'], maxVal),
      feedback: (json['feedback'] ?? json['remarks'] ?? '') as String,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student': studentId,
        'student_name': studentName,
        'grading_task': gradingTaskId,
        'grading_task_name': gradingTaskName,
        'score': score,
        'max_score': maxScore,
        'feedback': feedback,
        'is_pending_sync': isPendingSync,
      };
}

class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    this.schoolName = '',
    this.section = '',
    this.schoolYear = '',
    this.isActive = true,
    this.adviserId,
    this.adviserName = '',
    this.gradeLevelIds = const [],
    this.lessonPlanId,
    this.lessonPlanTitle = '',
    this.students = const [],
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_cls_*`
  final String name;
  final String schoolName;
  final String section;
  final String schoolYear;
  final bool isActive;
  final int? adviserId;
  final String adviserName;
  final List<int> gradeLevelIds;
  final String? lessonPlanId;
  final String lessonPlanTitle;
  final List<Student> students;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  factory Classroom.fromJson(Map<String, dynamic> json) {
    final advObj = json['adviser_detail'] ?? json['adviser'];
    int? aId;
    String aName = (json['adviser_username'] ?? '') as String;
    if (advObj is int) {
      aId = advObj;
    } else if (advObj is Map<String, dynamic>) {
      aId = (advObj['id'] ?? advObj['user_id']) as int?;
      aName = (advObj['username'] ?? aName) as String;
    }

    final lpObj = json['lesson_plan_detail'] ?? json['lesson_plan'];
    String? lpId;
    String lpTitle = (json['lesson_plan_title'] ?? '') as String;
    if (lpObj is int || lpObj is String) {
      lpId = lpObj.toString();
    } else if (lpObj is Map<String, dynamic>) {
      lpId = (lpObj['lp_id'] ?? lpObj['id'])?.toString();
      lpTitle = (lpObj['title'] ?? lpTitle) as String;
    }

    final glIds = <int>[];
    final rawGl = json['grade_levels'];
    if (rawGl is List) {
      for (final item in rawGl) {
        if (item is int) {
          glIds.add(item);
        } else if (item is Map<String, dynamic>) {
          final idVal = item['id'] ?? item['grade_level_id'];
          if (idVal is int) glIds.add(idVal);
        }
      }
    }

    final parsedStudents = <Student>[];
    final rawStudents = json['students'];
    if (rawStudents is List) {
      for (final item in rawStudents) {
        if (item is Map<String, dynamic>) {
          parsedStudents.add(Student.fromJson(item));
        }
      }
    }

    return Classroom(
      id: (json['classroom_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '') as String,
      schoolName: (json['school_name'] ?? '') as String,
      section: (json['section'] ?? '') as String,
      schoolYear: (json['school_year'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
      adviserId: aId,
      adviserName: aName,
      gradeLevelIds: glIds,
      lessonPlanId: lpId,
      lessonPlanTitle: lpTitle,
      students: parsedStudents,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'school_name': schoolName,
        'section': section,
        'school_year': schoolYear,
        'is_active': isActive,
        'adviser': adviserId,
        'adviser_username': adviserName,
        'grade_levels': gradeLevelIds,
        'lesson_plan': lessonPlanId,
        'lesson_plan_title': lessonPlanTitle,
        'students': students.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };

  Classroom copyWith({
    String? id,
    String? name,
    String? schoolName,
    String? section,
    String? schoolYear,
    bool? isActive,
    int? adviserId,
    String? adviserName,
    List<int>? gradeLevelIds,
    String? lessonPlanId,
    String? lessonPlanTitle,
    List<Student>? students,
    bool? isPendingSync,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolName: schoolName ?? this.schoolName,
      section: section ?? this.section,
      schoolYear: schoolYear ?? this.schoolYear,
      isActive: isActive ?? this.isActive,
      adviserId: adviserId ?? this.adviserId,
      adviserName: adviserName ?? this.adviserName,
      gradeLevelIds: gradeLevelIds ?? this.gradeLevelIds,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      lessonPlanTitle: lessonPlanTitle ?? this.lessonPlanTitle,
      students: students ?? this.students,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  static String encodeList(List<Classroom> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Classroom> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    final result = <Classroom>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        result.add(Classroom.fromJson(item));
      }
    }
    return result;
  }
}
