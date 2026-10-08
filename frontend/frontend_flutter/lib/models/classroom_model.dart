import 'package:hive/hive.dart';
import 'student_model.dart';

part 'classroom_model.g.dart';

@HiveType(typeId: 2)
class GradeLevelModel extends HiveObject {
  @HiveField(0)
  final int glId;

  @HiveField(1)
  final String gradeLevelName;

  GradeLevelModel({
    required this.glId,
    required this.gradeLevelName,
  });

  factory GradeLevelModel.fromJson(Map<String, dynamic> json) {
    return GradeLevelModel(
      glId: json['gl_id'] as int,
      gradeLevelName: json['grade_level_name'] as String? ?? 'Grade ${json['gl_id']}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gl_id': glId,
      'grade_level_name': gradeLevelName,
    };
  }
}

@HiveType(typeId: 3)
class LessonPlanSummaryModel extends HiveObject {
  @HiveField(0)
  final int lpId;

  @HiveField(1)
  final String lpTitle;

  @HiveField(2)
  final String learningArea;

  @HiveField(3)
  final String primaryLanguage;

  @HiveField(4)
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

@HiveType(typeId: 4)
class ClassroomModel extends HiveObject {
  @HiveField(0)
  final int? classroomId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String schoolName;

  @HiveField(3)
  final String? section;

  @HiveField(4)
  final String schoolYear;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final int? adviser;

  @HiveField(7)
  final List<StudentModel> students;

  @HiveField(8)
  final List<GradeLevelModel> gradeLevels;

  @HiveField(9)
  final LessonPlanSummaryModel? lessonPlan;

  @HiveField(10)
  final List<int> gradeLevelIds;

  @HiveField(11)
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

  List<StudentModel> getSortedStudents([StudentSortBy sortBy = StudentSortBy.nameAsc]) {
    final sortedList = List<StudentModel>.from(students);
    sortedList.sort((a, b) => a.compareTo(b, sortBy));
    return sortedList;
  }

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    final parsedGradeLevels = (json['grade_levels'] as List<dynamic>?)
            ?.map((item) => GradeLevelModel.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    final parsedGradeLevelIds = (json['grade_level_ids'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        parsedGradeLevels.map((gl) => gl.glId).toList();

    final parsedLessonPlan = json['lesson_plan'] != null
        ? LessonPlanSummaryModel.fromJson(json['lesson_plan'] as Map<String, dynamic>)
        : null;

    final parsedLessonPlanId = (json['lesson_plan_id'] as int?) ?? parsedLessonPlan?.lpId;

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
      gradeLevels: parsedGradeLevels,
      lessonPlan: parsedLessonPlan,
      gradeLevelIds: parsedGradeLevelIds,
      lessonPlanId: parsedLessonPlanId,
    );
  }

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
