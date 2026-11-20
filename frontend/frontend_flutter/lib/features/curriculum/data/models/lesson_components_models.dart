import 'json_parsers.dart';

class LessonFlow {
  const LessonFlow({
    required this.id,
    this.lessonPlanId = '',
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    this.stepOrder = 0,
    required this.stage,
    required this.description,
    this.timeMinutes = 10,
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final int stepOrder;
  final String stage;
  final String description;
  final int timeMinutes;
  final bool isPendingSync;

  String get phaseName => stage;
  String get activityDescription => description;
  int get durationMinutes => timeMinutes;

  factory LessonFlow.fromJson(Map<String, dynamic> json) {
    final idStr = asIdString(
      json['lf_id'] ?? json['lesson_flow_id'] ?? json['flow_id'] ?? json['id'] ?? json['pk'],
    );
    final rawOrder = json['step_order'] ?? json['order'] ?? int.tryParse(idStr);
    final lglRaw = json['lesson_grade_level'] ?? json['lgl_id'] ?? json['lgl'];
    String gName = asString(json['grade_level_name']);
    if (gName.isEmpty && lglRaw is Map<String, dynamic>) {
      final glObj = lglRaw['grade_level'];
      if (glObj is Map<String, dynamic>) {
        gName = asString(glObj['grade_level_name'] ?? glObj['name']);
      } else {
        gName = asString(lglRaw['grade_level_name']);
      }
    }

    return LessonFlow(
      id: idStr,
      lessonPlanId: asIdString(json['lp'] ?? json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: asNullableIdString(lglRaw),
      gradeLevelName: gName,
      stepOrder: asInt(rawOrder, 1),
      stage: asString(json['stage'] ?? json['phase_name'] ?? json['phase'] ?? json['title']),
      description: asString(
        json['description'] ?? json['activity_description'] ?? json['activity'],
      ),
      timeMinutes: asInt(
        json['time_minutes'] ?? json['duration_minutes'] ?? json['duration'],
        10,
      ),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  LessonFlow copyWith({
    String? id,
    String? lessonPlanId,
    String? lessonGradeLevelId,
    String? gradeLevelName,
    int? stepOrder,
    String? stage,
    String? description,
    int? timeMinutes,
    bool? isPendingSync,
  }) {
    return LessonFlow(
      id: id ?? this.id,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      lessonGradeLevelId: lessonGradeLevelId ?? this.lessonGradeLevelId,
      gradeLevelName: gradeLevelName ?? this.gradeLevelName,
      stepOrder: stepOrder ?? this.stepOrder,
      stage: stage ?? this.stage,
      description: description ?? this.description,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'lf_id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'step_order': stepOrder,
        'stage': stage,
        'description': description,
        'time_minutes': timeMinutes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonGrading {
  const LessonGrading({
    required this.id,
    this.lessonPlanId = '',
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    required this.taskName,
    this.taskDescription = '',
    this.gradeWeight = 0,
    this.maxScore = 0,
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final String taskName;
  final String taskDescription;
  final double gradeWeight;
  final int maxScore;
  final bool isPendingSync;

  String get criteriaName => taskName;
  String get rubricNotes => taskDescription;
  double get weightPercentage => gradeWeight;

  factory LessonGrading.fromJson(Map<String, dynamic> json) {
    final lglRaw = json['lesson_grade_level'] ?? json['lgl_id'] ?? json['lgl'];
    String gName = asString(json['grade_level_name']);
    if (gName.isEmpty && lglRaw is Map<String, dynamic>) {
      final glObj = lglRaw['grade_level'];
      if (glObj is Map<String, dynamic>) {
        gName = asString(glObj['grade_level_name'] ?? glObj['name']);
      } else {
        gName = asString(lglRaw['grade_level_name']);
      }
    }

    return LessonGrading(
      id: asIdString(
        json['lg_id'] ?? json['lesson_grading_id'] ?? json['grading_id'] ?? json['id'] ?? json['pk'],
      ),
      lessonPlanId: asIdString(json['lp'] ?? json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: asNullableIdString(lglRaw),
      gradeLevelName: gName,
      taskName: asString(
        json['task_name'] ?? json['criteria_name'] ?? json['criterion'] ?? json['title'],
      ),
      taskDescription: asString(
        json['task_description'] ?? json['rubric_notes'] ?? json['description'],
      ),
      gradeWeight: asDouble(
        json['grade_weight'] ?? json['weight_percentage'] ?? json['weight'],
      ),
      maxScore: asInt(json['max_score'] ?? json['total_score']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  LessonGrading copyWith({
    String? id,
    String? lessonPlanId,
    String? lessonGradeLevelId,
    String? gradeLevelName,
    String? taskName,
    String? taskDescription,
    double? gradeWeight,
    int? maxScore,
    bool? isPendingSync,
  }) {
    return LessonGrading(
      id: id ?? this.id,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      lessonGradeLevelId: lessonGradeLevelId ?? this.lessonGradeLevelId,
      gradeLevelName: gradeLevelName ?? this.gradeLevelName,
      taskName: taskName ?? this.taskName,
      taskDescription: taskDescription ?? this.taskDescription,
      gradeWeight: gradeWeight ?? this.gradeWeight,
      maxScore: maxScore ?? this.maxScore,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'lg_id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'task_name': taskName,
        'task_description': taskDescription,
        'grade_weight': gradeWeight,
        'max_score': maxScore,
        'is_pending_sync': isPendingSync,
      };
}

class LessonMaterial {
  const LessonMaterial({
    required this.id,
    this.lessonPlanId = '',
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    required this.title,
    this.materialType = 'DOCUMENT',
    this.resourceUrl = '',
    this.notes = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final String title;
  final String materialType;
  final String resourceUrl;
  final String notes;
  final bool isPendingSync;

  factory LessonMaterial.fromJson(Map<String, dynamic> json) {
    final lglRaw = json['lesson_grade_level'] ?? json['lgl_id'] ?? json['lgl'];
    String gName = asString(json['grade_level_name']);
    if (gName.isEmpty && lglRaw is Map<String, dynamic>) {
      final glObj = lglRaw['grade_level'];
      if (glObj is Map<String, dynamic>) {
        gName = asString(glObj['grade_level_name'] ?? glObj['name']);
      } else {
        gName = asString(lglRaw['grade_level_name']);
      }
    }

    return LessonMaterial(
      id: asIdString(json['material_id'] ?? json['lm_id'] ?? json['id'] ?? json['pk']),
      lessonPlanId: asIdString(json['lp'] ?? json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: asNullableIdString(lglRaw),
      gradeLevelName: gName,
      title: asString(json['title'] ?? json['material_title'] ?? json['name']),
      materialType: asString(json['material_type'] ?? json['type'], 'DOCUMENT'),
      resourceUrl: asString(json['resource_url'] ?? json['url'] ?? json['file']),
      notes: asString(json['notes'] ?? json['description']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  LessonMaterial copyWith({
    String? id,
    String? lessonPlanId,
    String? lessonGradeLevelId,
    String? gradeLevelName,
    String? title,
    String? materialType,
    String? resourceUrl,
    String? notes,
    bool? isPendingSync,
  }) {
    return LessonMaterial(
      id: id ?? this.id,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      lessonGradeLevelId: lessonGradeLevelId ?? this.lessonGradeLevelId,
      gradeLevelName: gradeLevelName ?? this.gradeLevelName,
      title: title ?? this.title,
      materialType: materialType ?? this.materialType,
      resourceUrl: resourceUrl ?? this.resourceUrl,
      notes: notes ?? this.notes,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'material_id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'title': title,
        'material_type': materialType,
        'resource_url': resourceUrl,
        'notes': notes,
        'is_pending_sync': isPendingSync,
      };
}
