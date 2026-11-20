import 'json_parsers.dart';

class LessonFlow {
  const LessonFlow({
    required this.id,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    required this.stepOrder,
    required this.phaseName,
    required this.activityDescription,
    this.durationMinutes = 10,
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final int stepOrder;
  final String phaseName;
  final String activityDescription;
  final int durationMinutes;
  final bool isPendingSync;

  factory LessonFlow.fromJson(Map<String, dynamic> json) {
    return LessonFlow(
      id: asString(json['lesson_flow_id'] ?? json['flow_id'] ?? json['id'] ?? json['pk']),
      lessonPlanId: asString(json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      stepOrder: asInt(json['step_order'] ?? json['order'], 1),
      phaseName: asString(json['phase_name'] ?? json['phase'] ?? json['title']),
      activityDescription: asString(
        json['activity_description'] ?? json['activity'] ?? json['description'],
      ),
      durationMinutes: asInt(json['duration_minutes'] ?? json['duration'], 10),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'step_order': stepOrder,
        'phase_name': phaseName,
        'activity_description': activityDescription,
        'duration_minutes': durationMinutes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonGrading {
  const LessonGrading({
    required this.id,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    required this.criteriaName,
    required this.weightPercentage,
    this.rubricNotes = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String criteriaName;
  final double weightPercentage;
  final String rubricNotes;
  final bool isPendingSync;

  factory LessonGrading.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_percentage'] ?? json['weight'] ?? 0;
    return LessonGrading(
      id: asString(
        json['lesson_grading_id'] ?? json['grading_id'] ?? json['id'] ?? json['pk'],
      ),
      lessonPlanId: asString(json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      criteriaName: asString(
        json['criteria_name'] ?? json['criterion'] ?? json['title'],
      ),
      weightPercentage: rawWeight is num
          ? rawWeight.toDouble()
          : double.tryParse(rawWeight.toString()) ?? 0.0,
      rubricNotes: asString(json['rubric_notes'] ?? json['description']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'criteria_name': criteriaName,
        'weight_percentage': weightPercentage,
        'rubric_notes': rubricNotes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonMaterial {
  const LessonMaterial({
    required this.id,
    required this.lessonPlanId,
    required this.title,
    this.materialType = 'DOCUMENT',
    this.resourceUrl = '',
    this.notes = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String title;
  final String materialType;
  final String resourceUrl;
  final String notes;
  final bool isPendingSync;

  factory LessonMaterial.fromJson(Map<String, dynamic> json) {
    return LessonMaterial(
      id: asString(json['material_id'] ?? json['id'] ?? json['pk']),
      lessonPlanId: asString(json['lesson_plan'] ?? json['lp_id']),
      title: asString(json['title'] ?? json['material_title'] ?? json['name']),
      materialType: asString(json['material_type'] ?? json['type'], 'DOCUMENT'),
      resourceUrl: asString(json['resource_url'] ?? json['url'] ?? json['file']),
      notes: asString(json['notes'] ?? json['description']),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'title': title,
        'material_type': materialType,
        'resource_url': resourceUrl,
        'notes': notes,
        'is_pending_sync': isPendingSync,
      };
}
