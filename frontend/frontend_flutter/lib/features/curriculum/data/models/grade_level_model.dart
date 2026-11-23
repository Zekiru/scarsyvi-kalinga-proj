import 'json_parsers.dart';
import 'lesson_components_models.dart';

class GradeLevel {
  const GradeLevel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory GradeLevel.fromJson(Map<String, dynamic> json) {
    return GradeLevel(
      id: asInt(json['gl_id'] ?? json['id']),
      name: asString(json['grade_level_name'] ?? json['name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'gl_id': id,
        'grade_level_name': name,
      };
}

class LessonGradeLevel {
  const LessonGradeLevel({
    required this.id,
    this.serverId,
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
  final int? serverId;
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

  bool get hasDetailedStandards =>
      contentStandard.isNotEmpty ||
      performanceStandard.isNotEmpty ||
      learningCompetencies.isNotEmpty ||
      learningObjectives.isNotEmpty ||
      learnerContext.isNotEmpty ||
      reflectionQuestions.isNotEmpty ||
      remediation.isNotEmpty ||
      enrichment.isNotEmpty;

  LessonGradeLevel copyWith({
    String? id,
    int? serverId,
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
      serverId: serverId ?? this.serverId,
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

  factory LessonGradeLevel.fromJson(Map<String, dynamic> json) {
    final numId = asNullableInt(json['id'] ?? json['lgl_id']);
    final rawId = json['id'] ?? json['lgl_id'];

    final glObj = json['grade_level'] is Map
        ? Map<String, dynamic>.from(json['grade_level'] as Map)
        : (json['gl'] is Map
            ? Map<String, dynamic>.from(json['gl'] as Map)
            : null);

    final resolvedGlName = asString(
      json['grade_level_name'] ?? glObj?['grade_level_name'] ?? glObj?['name'],
    );
    final resolvedGlId = asInt(
      glObj?['gl_id'] ?? glObj?['id'] ?? json['gl'] ?? json['gl_id'],
    );
    final resolvedLpId = asIdString(json['lp'] ?? json['lesson_plan']);
    final lglIdStr = numId?.toString() ?? asString(rawId);

    final parsedFlows = parseModelList(json['flows'], LessonFlow.fromJson)
        .map(
          (f) => f.copyWith(
            lessonPlanId:
                f.lessonPlanId.isEmpty ? resolvedLpId : f.lessonPlanId,
            lessonGradeLevelId: f.lessonGradeLevelId ?? lglIdStr,
            gradeLevelName: f.gradeLevelName.isEmpty && resolvedGlName.isNotEmpty
                ? resolvedGlName
                : f.gradeLevelName,
          ),
        )
        .toList();

    final parsedGradings =
        parseModelList(json['grading_tasks'], LessonGrading.fromJson)
            .map(
              (g) => g.copyWith(
                lessonPlanId:
                    g.lessonPlanId.isEmpty ? resolvedLpId : g.lessonPlanId,
                lessonGradeLevelId: g.lessonGradeLevelId ?? lglIdStr,
                gradeLevelName:
                    g.gradeLevelName.isEmpty && resolvedGlName.isNotEmpty
                        ? resolvedGlName
                        : g.gradeLevelName,
              ),
            )
            .toList();

    final parsedMaterials =
        parseModelList(json['materials'], LessonMaterial.fromJson)
            .map(
              (m) => m.copyWith(
                lessonPlanId:
                    m.lessonPlanId.isEmpty ? resolvedLpId : m.lessonPlanId,
                lessonGradeLevelId: m.lessonGradeLevelId ?? lglIdStr,
                gradeLevelName:
                    m.gradeLevelName.isEmpty && resolvedGlName.isNotEmpty
                        ? resolvedGlName
                        : m.gradeLevelName,
              ),
            )
            .toList();

    return LessonGradeLevel(
      id: lglIdStr,
      serverId: numId,
      lessonPlanId: resolvedLpId,
      gradeLevelId: resolvedGlId,
      gradeLevelName: resolvedGlName,
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
        json['i_objectives'] ?? json['learning_objectives'],
      ),
      learnerContext: asString(json['l_context']),
      reflectionQuestions: asString(json['w_reflection_questions']),
      remediation: asString(json['re_remediation']),
      enrichment: asString(json['re_enrichment']),
      flows: parsedFlows,
      gradingTasks: parsedGradings,
      materials: parsedMaterials,
      isPendingSync: json['isPendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': serverId ?? id,
        'lp': lessonPlanId,
        'gl': gradeLevelId,
        'grade_level': {
          'gl_id': gradeLevelId,
          'grade_level_name': gradeLevelName,
        },
        'grade_level_name': gradeLevelName,
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
        'isPendingSync': isPendingSync,
      };
}
