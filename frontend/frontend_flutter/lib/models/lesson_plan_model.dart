import 'lesson_grade_level_model.dart';

class LessonPlanModel {
  final int? lpId;
  final String lpTitle;
  final String learningArea;
  final String primaryLanguage;
  final String? suggestedDemographic;
  final String? learningModelDescription;
  final String? intentionsDescription;
  final String? notes;
  final List<LessonGradeLevelModel> gradeLevels;

  LessonPlanModel({
    this.lpId,
    required this.lpTitle,
    required this.learningArea,
    required this.primaryLanguage,
    this.suggestedDemographic,
    this.learningModelDescription,
    this.intentionsDescription,
    this.notes,
    this.gradeLevels = const [],
  });

  /// Factory for parsing GET responses from LessonPlanDetailSerializer
  factory LessonPlanModel.fromJson(Map<String, dynamic> json) {
    return LessonPlanModel(
      lpId: json['lp_id'] as int?,
      lpTitle: json['lp_title'] as String,
      learningArea: json['learning_area'] as String,
      primaryLanguage: json['primary_language'] as String,
      suggestedDemographic: json['suggested_demographic'] as String?,
      learningModelDescription: json['learning_model_description'] as String?,
      intentionsDescription: json['intentions_description'] as String?,
      notes: json['notes'] as String?,
      gradeLevels: (json['grade_levels_detail'] as List<dynamic>?)
              ?.map((item) => LessonGradeLevelModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Serializer for POST/PUT requests matching LessonPlanWriteSerializer
  Map<String, dynamic> toWriteJson() {
    return {
      if (lpId != null) 'lp_id': lpId,
      'lp_title': lpTitle,
      'learning_area': learningArea,
      'primary_language': primaryLanguage,
      'suggested_demographic': suggestedDemographic,
      'learning_model_description': learningModelDescription,
      'intentions_description': intentionsDescription,
      'notes': notes,
      'grade_levels': gradeLevels.map((gl) => gl.toWriteJson()).toList(),
    };
  }
}
