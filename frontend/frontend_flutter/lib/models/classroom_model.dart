import 'student_model.dart';

class GradeLevelModel {
  final int glId;
  final String gradeLevelName;

  GradeLevelModel({
    required this.glId,
    required this.gradeLevelName,
  });

  factory GradeLevelModel.fromJson(Map<String, dynamic> json) {
    return GradeLevelModel(
      glId: json['gl_id'] as int,
      gradeLevelName: json['grade_level_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gl_id': glId,
      'grade_level_name': gradeLevelName,
    };
  }
}

class LessonPlanSummaryModel {
  final int lpId;
  final String lpTitle;
  final String learningArea;
  final String primaryLanguage;
  final String? suggestedDemographic;

  LessonPlanSummaryModel({
    required this.lpId,
    required this.lpTitle,
    required this.learningArea,
    required this.primaryLanguage,
    this.suggestedDemographic,
  });

  factory LessonPlanSummaryModel.fromJson(Map<String, dynamic> json) {
    return LessonPlanSummaryModel(
      lpId: json['lp_id'] as int,
      lpTitle: json['lp_title'] as String,
      learningArea: json['learning_area'] as String,
      primaryLanguage: json['primary_language'] as String,
      suggestedDemographic: json['suggested_demographic'] as String?,
    );
  }
}

class ClassroomModel {
  final int? classroomId;
  final String name;
  final String schoolName;
  final String? section;
  final String schoolYear;
  final bool isActive;
  final int? adviser;
  final List<StudentModel> students;
  
  // Read Expansion Fields
  final List<GradeLevelModel> gradeLevels;
  final LessonPlanSummaryModel? lessonPlan;

  // Write IDs for POST / PUT operations
  final List<int> gradeLevelIds;
  final int? lessonPlanId;

  ClassroomModel({
    this.classroomId,
    required this.name,
    required this.schoolName,
    this.section,
    required this.schoolYear,
    this.isActive = true,
    this.adviser,
    this.students = const [],
    this.gradeLevels = const [],
    this.lessonPlan,
    this.gradeLevelIds = const [],
    this.lessonPlanId,
  });

  /// Non-destructive helper to return sorted students
  List<StudentModel> getSortedStudents([StudentSortBy sortBy = StudentSortBy.nameAsc]) {
    final sortedList = List<StudentModel>.from(students);
    sortedList.sort((a, b) => a.compareTo(b, sortBy));
    return sortedList;
  }

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
      classroomId: json['classroom_id'] as int?,
      name: json['name'] as String,
      schoolName: json['school_name'] as String,
      section: json['section'] as String?,
      schoolYear: json['school_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      adviser: json['adviser'] as int?,
      students: (json['students'] as List<dynamic>?)
              ?.map((item) => StudentModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      gradeLevels: (json['grade_levels'] as List<dynamic>?)
              ?.map((item) => GradeLevelModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      lessonPlan: json['lesson_plan'] != null
          ? LessonPlanSummaryModel.fromJson(json['lesson_plan'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serializer for creating/updating classrooms matching DRF write schema
  Map<String, dynamic> toWriteJson() {
    return {
      if (classroomId != null) 'classroom_id': classroomId,
      'name': name,
      'school_name': schoolName,
      'section': section,
      'school_year': schoolYear,
      'is_active': isActive,
      if (adviser != null) 'adviser': adviser,
      'grade_level_ids': gradeLevelIds.isNotEmpty
          ? gradeLevelIds
          : gradeLevels.map((gl) => gl.glId).toList(),
      if (lessonPlanId != null) 'lesson_plan_id': lessonPlanId,
      'students': students.map((s) => s.toJson()).toList(),
    };
  }
}
