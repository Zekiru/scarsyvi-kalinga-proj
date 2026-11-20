import 'json_parsers.dart';

class GradeLevel {
  const GradeLevel({
    required this.id,
    required this.name,
    this.levelOrder = 0,
    this.description = '',
  });

  final int id;
  final String name;
  final int levelOrder;
  final String description;

  factory GradeLevel.fromJson(Map<String, dynamic> json) {
    return GradeLevel(
      id: asInt(json['gl_id'] ?? json['grade_level_id'] ?? json['id'] ?? json['pk']),
      name: asString(json['grade_level_name'] ?? json['name'] ?? json['grade_name']),
      levelOrder: asInt(json['level_order'] ?? json['order']),
      description: asString(json['description']),
    );
  }

  Map<String, dynamic> toJson() => {
        'gl_id': id,
        'grade_level_name': name,
        'level_order': levelOrder,
        'description': description,
      };
}

class LessonGradeLevel {
  const LessonGradeLevel({
    required this.id,
    required this.lessonPlanId,
    required this.gradeLevelId,
    this.gradeLevelName = '',
    this.specificObjectives = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final int gradeLevelId;
  final String gradeLevelName;
  final String specificObjectives;
  final bool isPendingSync;

  factory LessonGradeLevel.fromJson(Map<String, dynamic> json) {
    final glObj = json['grade_level_detail'] ?? json['grade_level'];
    int glId = asInt(json['gl_id']);
    String glName = asString(json['grade_level_name']);

    if (glObj is Map<String, dynamic>) {
      glId = asInt(glObj['gl_id'] ?? glObj['id'] ?? glObj['grade_level_id'], glId);
      glName = asString(
        glObj['grade_level_name'] ?? glObj['name'] ?? glObj['grade_name'],
        glName,
      );
    } else if (glObj != null && glId == 0) {
      glId = asInt(glObj);
    }

    return LessonGradeLevel(
      id: asString(
        json['lesson_grade_level_id'] ?? json['id'] ?? json['gl_id'] ?? json['pk'],
      ),
      lessonPlanId: asString(json['lesson_plan'] ?? json['lp_id']),
      gradeLevelId: glId,
      gradeLevelName: glName,
      specificObjectives: asString(json['specific_objectives'] ?? json['objectives']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'gl_id': gradeLevelId,
        'grade_level': gradeLevelId,
        'grade_level_name': gradeLevelName,
        'specific_objectives': specificObjectives,
        'is_pending_sync': isPendingSync,
      };
}
