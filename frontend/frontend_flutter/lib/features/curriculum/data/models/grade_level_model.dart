import 'json_parsers.dart';
import 'lesson_components_models.dart';

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
    this.contentStandard = '',
    this.performanceStandard = '',
    this.learningCompetencies = '',
    this.learningObjectives = '',
    this.learnerContext = '',
    this.reflectionQuestions = '',
    this.remediation = '',
    this.enrichment = '',
    this.flows = const [],
    this.gradingTasks = const [],
    this.materials = const [],
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final int gradeLevelId;
  final String gradeLevelName;
  final String contentStandard;
  final String performanceStandard;
  final String learningCompetencies;
  final String learningObjectives;
  final String learnerContext;
  final String reflectionQuestions;
  final String remediation;
  final String enrichment;
  final List<LessonFlow> flows;
  final List<LessonGrading> gradingTasks;
  final List<LessonMaterial> materials;
  final bool isPendingSync;

  String get specificObjectives => learningObjectives;

  bool get hasDetailedStandards =>
      contentStandard.isNotEmpty ||
      performanceStandard.isNotEmpty ||
      learningCompetencies.isNotEmpty ||
      learningObjectives.isNotEmpty ||
      learnerContext.isNotEmpty ||
      reflectionQuestions.isNotEmpty ||
      remediation.isNotEmpty ||
      enrichment.isNotEmpty;

  factory LessonGradeLevel.fromJson(Map<String, dynamic> json) {
    final glObj = json['grade_level'] ?? json['grade_level_detail'] ?? json['gl_detail'];
    int glId = asInt(json['gl'] ?? json['gl_id'] ?? json['grade_level_id']);
    String glName = asString(json['grade_level_name'] ?? json['grade_name']);

    if (glObj is Map<String, dynamic>) {
      glId = asInt(glObj['gl_id'] ?? glObj['id'] ?? glObj['grade_level_id'], glId);
      glName = asString(
        glObj['grade_level_name'] ?? glObj['name'] ?? glObj['grade_name'],
        glName,
      );
    } else if (glObj != null && glId == 0) {
      glId = asInt(glObj);
    }

    final idStr = asIdString(
      json['id'] ?? json['lesson_grade_level_id'] ?? json['lgl_id'] ?? json['pk'],
    );
    final lpStr = asIdString(json['lp'] ?? json['lesson_plan'] ?? json['lp_id']);
    final resolvedGradeName = glName.isNotEmpty ? glName : 'Grade $glId';

    final parsedFlows = parseModelList(
      json['flows'] ?? json['lesson_flows'],
      LessonFlow.fromJson,
    )
        .map((f) => f.gradeLevelName.isEmpty
            ? f.copyWith(
                gradeLevelName: resolvedGradeName,
                lessonPlanId: lpStr,
                lessonGradeLevelId: f.lessonGradeLevelId ?? (idStr.isNotEmpty ? idStr : null),
              )
            : f)
        .toList();

    final parsedGradings = parseModelList(
      json['grading_tasks'] ?? json['gradings'] ?? json['lesson_gradings'],
      LessonGrading.fromJson,
    )
        .map((g) => g.gradeLevelName.isEmpty
            ? g.copyWith(
                gradeLevelName: resolvedGradeName,
                lessonPlanId: lpStr,
                lessonGradeLevelId: g.lessonGradeLevelId ?? (idStr.isNotEmpty ? idStr : null),
              )
            : g)
        .toList();

    final parsedMaterials = parseModelList(
      json['materials'] ?? json['lesson_materials'],
      LessonMaterial.fromJson,
    )
        .map((m) => m.gradeLevelName.isEmpty
            ? m.copyWith(
                gradeLevelName: resolvedGradeName,
                lessonPlanId: lpStr,
                lessonGradeLevelId: m.lessonGradeLevelId ?? (idStr.isNotEmpty ? idStr : null),
              )
            : m)
        .toList();

    return LessonGradeLevel(
      id: idStr,
      lessonPlanId: lpStr,
      gradeLevelId: glId,
      gradeLevelName: glName,
      contentStandard: asString(
        json['i_content_standard'] ?? json['content_standard'],
      ),
      performanceStandard: asString(
        json['i_performance_standard'] ?? json['performance_standard'],
      ),
      learningCompetencies: asString(
        json['i_competencies_codes'] ?? json['learning_competencies'],
      ),
      learningObjectives: asString(
        json['i_objectives'] ?? json['learning_objectives'] ?? json['specific_objectives'],
      ),
      learnerContext: asString(json['l_context'] ?? json['learner_context']),
      reflectionQuestions: asString(
        json['w_reflection_questions'] ?? json['reflection_questions'],
      ),
      remediation: asString(json['re_remediation'] ?? json['remediation']),
      enrichment: asString(json['re_enrichment'] ?? json['enrichment']),
      flows: parsedFlows,
      gradingTasks: parsedGradings,
      materials: parsedMaterials,
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  LessonGradeLevel copyWith({
    String? id,
    String? lessonPlanId,
    int? gradeLevelId,
    String? gradeLevelName,
    String? contentStandard,
    String? performanceStandard,
    String? learningCompetencies,
    String? learningObjectives,
    String? learnerContext,
    String? reflectionQuestions,
    String? remediation,
    String? enrichment,
    List<LessonFlow>? flows,
    List<LessonGrading>? gradingTasks,
    List<LessonMaterial>? materials,
    bool? isPendingSync,
  }) {
    return LessonGradeLevel(
      id: id ?? this.id,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      gradeLevelId: gradeLevelId ?? this.gradeLevelId,
      gradeLevelName: gradeLevelName ?? this.gradeLevelName,
      contentStandard: contentStandard ?? this.contentStandard,
      performanceStandard: performanceStandard ?? this.performanceStandard,
      learningCompetencies: learningCompetencies ?? this.learningCompetencies,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      learnerContext: learnerContext ?? this.learnerContext,
      reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
      remediation: remediation ?? this.remediation,
      enrichment: enrichment ?? this.enrichment,
      flows: flows ?? this.flows,
      gradingTasks: gradingTasks ?? this.gradingTasks,
      materials: materials ?? this.materials,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lp': lessonPlanId,
        'gl': gradeLevelId,
        'grade_level': {
          'gl_id': gradeLevelId,
          'grade_level_name': gradeLevelName,
        },
        'i_content_standard': contentStandard,
        'i_performance_standard': performanceStandard,
        'i_competencies_codes': learningCompetencies,
        'i_objectives': learningObjectives,
        'l_context': learnerContext,
        'w_reflection_questions': reflectionQuestions,
        're_remediation': remediation,
        're_enrichment': enrichment,
        'flows': flows.map((e) => e.toJson()).toList(),
        'grading_tasks': gradingTasks.map((e) => e.toJson()).toList(),
        'materials': materials.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };
}
