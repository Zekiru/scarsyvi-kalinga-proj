import 'dart:convert';
import '../../curriculum/data/models/json_parsers.dart';

typedef JsonMap = Map<String, dynamic>;

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

  final String id;
  final String firstName;
  final String lastName;
  final String gender;
  final String lrn;
  final int? gradeLevelId;
  final String gradeLevelName;
  final double? gradeAverage;
  final double? attendanceAverage;
  final bool isPendingSync;

  String get fullName => '$firstName $lastName'.trim();
  String get formalName =>
      lastName.isNotEmpty ? '$lastName, $firstName' : firstName;

  factory Student.fromJson(JsonMap json) {
    final glObj = json['grade_level_detail'] ?? json['grade_level'];
    int? glId;
    String glName = asString(json['grade_level_name']);

    if (glObj is Map) {
      final glMap = JsonMap.from(glObj);
      glId = asNullableInt(
        glMap['gl_id'] ?? glMap['id'] ?? glMap['grade_level_id'],
      );
      glName = asString(
        glMap['grade_level_name'] ?? glMap['name'] ?? glMap['grade_name'],
        glName,
      );
    } else {
      glId = asNullableInt(glObj);
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final numericId = asNullableInt(json['student_id'] ?? json['id']);
    final rawId = json['student_id'] ?? json['id'];

    return Student(
      id: numericId?.toString() ?? asString(rawId),
      firstName: asString(json['first_name']),
      lastName: asString(json['last_name']),
      gender: asString(json['gender']),
      lrn: asString(json['lrn']),
      gradeLevelId: glId,
      gradeLevelName: glName,
      gradeAverage: parseNullableDouble(json['grade_average']),
      attendanceAverage: parseNullableDouble(json['attendance_average']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  JsonMap toJson() => {
        'student_id': int.tryParse(id) ?? id,
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

  factory StudentAttendanceEntry.fromJson(JsonMap json) {
    final stuObj = json['student_detail'] ?? json['student'];
    String sId = '';
    String sName = asString(json['student_name']);

    if (stuObj is Map) {
      final stuMap = JsonMap.from(stuObj);
      sId = asIdString(stuMap['student_id'] ?? stuMap['id']);
      final fn = asString(stuMap['first_name']);
      final ln = asString(stuMap['last_name']);
      if (sName.isEmpty) sName = '$fn $ln'.trim();
    } else if (stuObj != null) {
      sId = stuObj.toString();
    }

    return StudentAttendanceEntry(
      studentId: sId,
      studentName: sName,
      status: AttendanceStatus.fromString(json['status']?.toString()),
      notes: asString(json['notes']),
    );
  }

  JsonMap toJson() => {
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
  final String date;
  final String remarks;
  final List<StudentAttendanceEntry> records;
  final bool isPendingSync;

  int get presentCount =>
      records.where((r) => r.status == AttendanceStatus.present).length;
  int get lateCount =>
      records.where((r) => r.status == AttendanceStatus.late).length;
  int get absentCount =>
      records.where((r) => r.status == AttendanceStatus.absent).length;
  int get excusedCount =>
      records.where((r) => r.status == AttendanceStatus.excused).length;

  factory AttendanceSession.fromJson(JsonMap json) {
    final parsedRecords = <StudentAttendanceEntry>[];
    final rawRecs = json['records'] ?? json['attendances'];
    if (rawRecs is List) {
      for (final item in rawRecs) {
        if (item is Map) {
          parsedRecords.add(
            StudentAttendanceEntry.fromJson(JsonMap.from(item)),
          );
        }
      }
    }

    return AttendanceSession(
      id: asIdString(json['session_id'] ?? json['id']),
      classroomId: asIdString(json['classroom']),
      date: asString(json['date']),
      remarks: asString(json['remarks']),
      records: parsedRecords,
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  JsonMap toJson() => {
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
    this.submittedAt,
    this.isPendingSync = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String gradingTaskId;
  final String gradingTaskName;
  final double score;
  final double maxScore;
  final String feedback;
  final String? submittedAt;
  final bool isPendingSync;

  factory StudentGrade.fromJson(JsonMap json) {
    final stuObj = json['student_detail'] ?? json['student'];
    String sId = '';
    String sName = asString(json['student_name']);

    if (stuObj is Map) {
      final stuMap = JsonMap.from(stuObj);
      sId = asIdString(stuMap['student_id'] ?? stuMap['id']);
      final fn = asString(stuMap['first_name']);
      final ln = asString(stuMap['last_name']);
      if (sName.isEmpty) sName = '$fn $ln'.trim();
    } else if (stuObj != null) {
      sId = stuObj.toString();
    }

    final taskObj = json['grading_task_detail'] ?? json['grading_task'];
    String tId = '';
    String tName = asString(
      json['task_name'] ??
          json['grading_task_name'] ??
          json['criteria_name'],
    );
    double maxVal = 100.0;

    if (taskObj is Map) {
      final taskMap = JsonMap.from(taskObj);
      tId = asIdString(
        taskMap['lg_id'] ?? taskMap['lesson_grading_id'] ?? taskMap['id'],
      );
      tName = asString(
        taskMap['task_name'] ?? taskMap['criteria_name'] ?? taskMap['title'],
        tName,
      );
      final rawMax = taskMap['max_score'];
      if (rawMax != null) maxVal = asDouble(rawMax, maxVal);
    } else if (taskObj != null) {
      tId = taskObj.toString();
    }

    return StudentGrade(
      id: asIdString(json['grade_id'] ?? json['id']),
      studentId: sId,
      studentName: sName,
      gradingTaskId: tId,
      gradingTaskName: tName,
      score: asDouble(json['score']),
      maxScore: asDouble(json['max_score'], maxVal),
      feedback: asString(json['feedback'] ?? json['remarks']),
      submittedAt: json['submitted_at']?.toString(),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  JsonMap toJson() => {
        'id': id,
        'student': studentId,
        'student_name': studentName,
        'grading_task': gradingTaskId,
        'task_name': gradingTaskName,
        'score': score,
        'max_score': maxScore,
        'feedback': feedback,
        'submitted_at': submittedAt,
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
    this.gradeLevelNames = const [],
    this.lessonPlanId,
    this.lessonPlanTitle = '',
    this.studentCount = 0,
    this.students = const [],
    this.isPendingSync = false,
  });

  final String id;
  final String name;
  final String schoolName;
  final String section;
  final String schoolYear;
  final bool isActive;
  final int? adviserId;
  final String adviserName;
  final List<int> gradeLevelIds;
  final List<String> gradeLevelNames;
  final String? lessonPlanId;
  final String lessonPlanTitle;
  final int studentCount;
  final List<Student> students;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;
  int get effectiveStudentCount =>
      students.isNotEmpty ? students.length : studentCount;

  factory Classroom.fromJson(JsonMap json) {
    final advObj = json['adviser_detail'] ?? json['adviser'];
    int? aId;
    String aName = asString(json['adviser_username']);
    if (advObj is Map) {
      final advMap = JsonMap.from(advObj);
      aId = asNullableInt(advMap['id'] ?? advMap['user_id'] ?? advMap['pk']);
      final first = asString(advMap['first_name']);
      final last = asString(advMap['last_name']);
      final full = '$first $last'.trim();
      aName = full.isNotEmpty ? full : asString(advMap['username'], aName);
    } else {
      aId = asNullableInt(advObj);
    }

    final lpObj = json['lesson_plan_detail'] ?? json['lesson_plan'];
    String? lpId;
    String lpTitle = asString(json['lesson_plan_title']);
    if (lpObj is Map) {
      final lpMap = JsonMap.from(lpObj);
      lpId = asNullableIdString(lpMap['lp_id'] ?? lpMap['id']);
      lpTitle = asString(lpMap['lp_title'] ?? lpMap['title'], lpTitle);
    } else if (lpObj != null) {
      lpId = asNullableIdString(lpObj);
    }

    final glIds = <int>[];
    final glNames = <String>[];
    final rawGl = json['grade_levels'];
    if (rawGl is List) {
      for (final item in rawGl) {
        if (item is Map) {
          final glMap = JsonMap.from(item);
          final idVal = asNullableInt(
            glMap['gl_id'] ?? glMap['id'] ?? glMap['grade_level_id'],
          );
          if (idVal != null && !glIds.contains(idVal)) glIds.add(idVal);
          final nameVal = asString(
            glMap['grade_level_name'] ?? glMap['name'] ?? glMap['grade_name'],
          );
          if (nameVal.isNotEmpty && !glNames.contains(nameVal)) {
            glNames.add(nameVal);
          }
        } else {
          final idVal = asNullableInt(item);
          if (idVal != null && !glIds.contains(idVal)) glIds.add(idVal);
        }
      }
    }
    if (glNames.isEmpty && json['grade_level_names'] is List) {
      for (final n in json['grade_level_names'] as List) {
        final s = asString(n);
        if (s.isNotEmpty) glNames.add(s);
      }
    }

    final parsedStudents = parseModelList(json['students'], Student.fromJson);
    final rawCount = asInt(json['student_count']);
    final numericId = asNullableInt(json['classroom_id'] ?? json['id']);
    final rawId = json['classroom_id'] ?? json['id'];

    return Classroom(
      id: numericId?.toString() ?? asString(rawId),
      name: asString(json['name']),
      schoolName: asString(json['school_name']),
      section: asString(json['section']),
      schoolYear: asString(json['school_year']),
      isActive: asBool(json['is_active'], true),
      adviserId: aId,
      adviserName: aName,
      gradeLevelIds: glIds,
      gradeLevelNames: glNames,
      lessonPlanId: lpId,
      lessonPlanTitle: lpTitle,
      studentCount:
          parsedStudents.isNotEmpty ? parsedStudents.length : rawCount,
      students: parsedStudents,
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  JsonMap toJson() => {
        'classroom_id': serverId ?? id,
        'name': name,
        'school_name': schoolName,
        'section': section,
        'school_year': schoolYear,
        'is_active': isActive,
        'adviser': adviserId,
        'adviser_username': adviserName,
        'grade_levels': gradeLevelIds,
        'grade_level_names': gradeLevelNames,
        'lesson_plan': lessonPlanId,
        'lesson_plan_title': lessonPlanTitle,
        'student_count': effectiveStudentCount,
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
    List<String>? gradeLevelNames,
    String? lessonPlanId,
    bool clearLessonPlan = false,
    String? lessonPlanTitle,
    int? studentCount,
    List<Student>? students,
    bool? isPendingSync,
  }) {
    final nextStudents = students ?? this.students;
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
      gradeLevelNames: gradeLevelNames ?? this.gradeLevelNames,
      lessonPlanId:
          clearLessonPlan ? null : (lessonPlanId ?? this.lessonPlanId),
      lessonPlanTitle:
          clearLessonPlan ? '' : (lessonPlanTitle ?? this.lessonPlanTitle),
      studentCount: studentCount ??
          (nextStudents.isNotEmpty ? nextStudents.length : this.studentCount),
      students: nextStudents,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  static String encodeList(List<Classroom> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Classroom> decodeList(String raw) =>
      parseModelList(jsonDecode(raw), Classroom.fromJson);
}
