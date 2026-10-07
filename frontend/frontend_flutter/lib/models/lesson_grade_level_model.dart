import 'lesson_flow_model.dart';
import 'lesson_grading_model.dart';
import 'lesson_grade_material_model.dart';

class LessonGradeLevelModel {
  final int glId;
  final String? gradeLevelName;
  final String? iContentStandard;
  final String? iPerformanceStandard;
  final String? iCompetenciesCodes;
  final String? iObjectives;
  final String? lContext;
  final String? wReflectionQuestions;
  final String? reRemediation;
  final String? reEnrichment;
  final List<LessonFlowModel> flows;
  final List<LessonGradingModel> gradingTasks;
  final List<LessonGradeMaterialModel> materialsDetail;
  final List<int> materialIds; // Used for write (POST/PUT) payloads

  LessonGradeLevelModel({
    required this.glId,
    this.gradeLevelName,
    this.iContentStandard,
    this.iPerformanceStandard,
    this.iCompetenciesCodes,
    this.iObjectives,
    this.lContext,
    this.wReflectionQuestions,
    this.reRemediation,
    this.reEnrichment,
    this.flows = const [],
    this.gradingTasks = const [],
    this.materialsDetail = const [],
    this.materialIds = const [],
  });

  factory LessonGradeLevelModel.fromJson(Map<String, dynamic> json) {
    final rawMaterialsDetail = (json['materials_detail'] as List<dynamic>?)
            ?.map((item) => LessonGradeMaterialModel.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    final extractedMaterialIds = (json['material_ids'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        rawMaterialsDetail.map((m) => m.material.materialId).toList();

    return LessonGradeLevelModel(
      glId: json['gl_id'] as int,
      gradeLevelName: json['grade_level_name'] as String?,
      iContentStandard: json['i_content_standard'] as String?,
      iPerformanceStandard: json['i_performance_standard'] as String?,
      iCompetenciesCodes: json['i_competencies_codes'] as String?,
      iObjectives: json['i_objectives'] as String?,
      lContext: json['l_context'] as String?,
      wReflectionQuestions: json['w_reflection_questions'] as String?,
      reRemediation: json['re_remediation'] as String?,
      reEnrichment: json['re_enrichment'] as String?,
      flows: (json['flows'] as List<dynamic>?)
              ?.map((item) => LessonFlowModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      gradingTasks: (json['grading_tasks'] as List<dynamic>?)
              ?.map((item) => LessonGradingModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      materialsDetail: rawMaterialsDetail,
      materialIds: extractedMaterialIds,
    );
  }

  /// Output serializer for POST/PUT requests matching LessonGradeLevelWriteSerializer
  Map<String, dynamic> toWriteJson() {
    return {
      'gl_id': glId,
      'i_content_standard': iContentStandard,
      'i_performance_standard': iPerformanceStandard,
      'i_competencies_codes': iCompetenciesCodes,
      'i_objectives': iObjectives,
      'l_context': lContext,
      'w_reflection_questions': wReflectionQuestions,
      're_remediation': reRemediation,
      're_enrichment': reEnrichment,
      'flows': flows.map((f) => f.toJson()).toList(),
      'grading_tasks': gradingTasks.map((g) => g.toJson()).toList(),
      'material_ids': materialIds,
    };
  }
}
