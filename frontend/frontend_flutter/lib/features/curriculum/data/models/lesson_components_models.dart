import 'json_parsers.dart';

class LessonFlow {
  const LessonFlow({
    required this.id,
    this.serverId,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    required this.stepOrder,
    required this.stage,
    required this.description,
    this.timeMinutes = 10,
    this.isPendingSync = false,
  });

  final String id;
  final int? serverId;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final int stepOrder;
  final String stage;
  final String description;
  final int timeMinutes;
  final bool isPendingSync;

  LessonFlow copyWith({
    String? id,
    int? serverId,
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
      serverId: serverId ?? this.serverId,
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

  factory LessonFlow.fromJson(Map<String, dynamic> json) {
    final numId = asNullableInt(json['lf_id'] ?? json['flow_id'] ?? json['id']);
    final rawId = json['lf_id'] ?? json['flow_id'] ?? json['id'];

    final lglObj = json['lesson_grade_level'] is Map
        ? Map<String, dynamic>.from(json['lesson_grade_level'] as Map)
        : null;
    final glObj = lglObj?['gl'] is Map
        ? Map<String, dynamic>.from(lglObj!['gl'] as Map)
        : null;

    return LessonFlow(
      id: numId?.toString() ?? asString(rawId),
      serverId: numId,
      lessonPlanId: asIdString(
        json['lesson_plan'] ?? json['lp'] ?? lglObj?['lp'],
      ),
      lessonGradeLevelId: asNullableIdString(json['lesson_grade_level']),
      gradeLevelName: asString(
        json['grade_level_name'] ??
            lglObj?['grade_level_name'] ??
            glObj?['grade_level_name'],
      ),
      stepOrder: asInt(
        json['step_order'] ?? json['order'] ?? numId,
        1,
      ),
      stage: asString(
        json['stage'] ?? json['step_title'] ?? json['phase'] ?? json['title'],
        'Activity',
      ),
      description: asString(
        json['description'] ?? json['activities'] ?? json['teacher_activity'],
      ),
      timeMinutes: asInt(
        json['time_minutes'] ?? json['duration_minutes'] ?? json['minutes'],
        10,
      ),
      isPendingSync: json['isPendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'lf_id': serverId ?? id,
        'id': serverId ?? id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'step_order': stepOrder,
        'stage': stage,
        'description': description,
        'time_minutes': timeMinutes,
        'isPendingSync': isPendingSync,
      };
}

class LessonGrading {
  const LessonGrading({
    required this.id,
    this.serverId,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    required this.taskName,
    this.taskDescription = '',
    this.gradeWeight = 0,
    this.maxScore = 10,
    this.isPendingSync = false,
  });

  final String id;
  final int? serverId;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final String taskName;
  final String taskDescription;
  final double gradeWeight;
  final int maxScore;
  final bool isPendingSync;

  // Backward-compatible getters for classrooms feature
  String get criteriaName => taskName;
  double get weightPercentage => gradeWeight;

  LessonGrading copyWith({
    String? id,
    int? serverId,
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
      serverId: serverId ?? this.serverId,
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

  factory LessonGrading.fromJson(Map<String, dynamic> json) {
    final numId =
        asNullableInt(json['lg_id'] ?? json['grading_id'] ?? json['id']);
    final rawId = json['lg_id'] ?? json['grading_id'] ?? json['id'];

    final lglObj = json['lesson_grade_level'] is Map
        ? Map<String, dynamic>.from(json['lesson_grade_level'] as Map)
        : null;
    final glObj = lglObj?['gl'] is Map
        ? Map<String, dynamic>.from(lglObj!['gl'] as Map)
        : null;

    return LessonGrading(
      id: numId?.toString() ?? asString(rawId),
      serverId: numId,
      lessonPlanId: asIdString(
        json['lesson_plan'] ?? json['lp'] ?? lglObj?['lp'],
      ),
      lessonGradeLevelId: asNullableIdString(json['lesson_grade_level']),
      gradeLevelName: asString(
        json['grade_level_name'] ??
            lglObj?['grade_level_name'] ??
            glObj?['grade_level_name'],
      ),
      taskName: asString(
        json['task_name'] ?? json['criteria_name'] ?? json['title'],
        'Assessment Task',
      ),
      taskDescription: asString(
        json['task_description'] ?? json['description'],
      ),
      gradeWeight: asDouble(json['grade_weight'] ?? json['weight']),
      maxScore: asInt(json['max_score'], 10),
      isPendingSync: json['isPendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'lg_id': serverId ?? id,
        'id': serverId ?? id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'task_name': taskName,
        'task_description': taskDescription,
        'grade_weight': gradeWeight,
        'max_score': maxScore,
        'isPendingSync': isPendingSync,
      };
}

class LessonMaterial {
  const LessonMaterial({
    required this.id,
    this.serverId,
    this.materialServerId,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    this.gradeLevelName = '',
    required this.title,
    this.materialType = 'PDF',
    this.resourceUrl = '',
    this.notes = '',
    this.isPendingSync = false,
  });

  final String id;
  final int? serverId;
  final int? materialServerId;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String gradeLevelName;
  final String title;
  final String materialType;
  final String resourceUrl;
  final String notes;
  final bool isPendingSync;

  LessonMaterial copyWith({
    String? id,
    int? serverId,
    int? materialServerId,
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
      serverId: serverId ?? this.serverId,
      materialServerId: materialServerId ?? this.materialServerId,
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

  factory LessonMaterial.fromJson(Map<String, dynamic> json) {
    final nestedMaterial = json['material'] is Map
        ? Map<String, dynamic>.from(json['material'] as Map)
        : null;

    final numId = asNullableInt(
      json['lgm_id'] ?? json['material_id'] ?? json['id'],
    );
    final rawId = json['lgm_id'] ?? json['material_id'] ?? json['id'];

    final matId = asNullableInt(
      nestedMaterial?['material_id'] ??
          nestedMaterial?['id'] ??
          json['material_id'],
    );

    final lglObj = json['lesson_grade_level'] is Map
        ? Map<String, dynamic>.from(json['lesson_grade_level'] as Map)
        : null;
    final glObj = lglObj?['gl'] is Map
        ? Map<String, dynamic>.from(lglObj!['gl'] as Map)
        : null;

    return LessonMaterial(
      id: numId?.toString() ?? asString(rawId),
      serverId: numId,
      materialServerId: matId,
      lessonPlanId: asIdString(
        json['lesson_plan'] ?? json['lp'] ?? lglObj?['lp'],
      ),
      lessonGradeLevelId: asNullableIdString(json['lesson_grade_level']),
      gradeLevelName: asString(
        json['grade_level_name'] ??
            lglObj?['grade_level_name'] ??
            glObj?['grade_level_name'],
      ),
      title: asString(
        nestedMaterial?['file_name'] ??
            nestedMaterial?['title'] ??
            json['file_name'] ??
            json['title'],
        'Untitled Material',
      ),
      materialType: asString(
        nestedMaterial?['file_type'] ??
            nestedMaterial?['material_type'] ??
            json['file_type'] ??
            json['material_type'],
        'PDF',
      ),
      resourceUrl: asString(
        nestedMaterial?['file_url'] ??
            nestedMaterial?['resource_url'] ??
            json['file_url'] ??
            json['resource_url'],
      ),
      notes: asString(
        json['usage_instructions'] ??
            nestedMaterial?['description'] ??
            json['notes'] ??
            json['description'],
      ),
      isPendingSync: json['isPendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': serverId ?? id,
        if (materialServerId != null) 'material_id': materialServerId,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'grade_level_name': gradeLevelName,
        'file_name': title,
        'title': title,
        'file_type': materialType,
        'material_type': materialType,
        'file_url': resourceUrl,
        'resource_url': resourceUrl,
        'usage_instructions': notes,
        'notes': notes,
        'isPendingSync': isPendingSync,
      };
}
