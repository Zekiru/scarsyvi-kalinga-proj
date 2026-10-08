import 'package:hive/hive.dart';
import 'lesson_grade_level_model.dart';

part 'lesson_plan_model.g.dart';

@HiveType(typeId: 9)
class LessonPlanModel extends HiveObject {
  @HiveField(0)
  final int? lpId;

  @HiveField(1)
  final String lpTitle;

  @HiveField(2)
  final String learningArea;

  @HiveField(3)
  final String primaryLanguage;

  @HiveField(4)
  final String? suggestedDemographic;

  @HiveField(5)
  final String? learningModelDescription;

  @HiveField(6)
  final String? intentionsDescription;

  @HiveField(7)
  final String? notes;

  @HiveField(8)
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

  factory LessonPlanModel.fromJson(Map<String, dynamic> json) {
    final rawGradeLevels = json['grade_levels_detail'] ?? json['grade_levels'];

    return LessonPlanModel(
      lpId: json['lp_id'] as int?,
      lpTitle: json['lp_title'] as String,
      learningArea: json['learning_area'] as String,
      primaryLanguage: json['primary_language'] as String,
      suggestedDemographic: json['suggested_demographic'] as String?,
      learningModelDescription: json['learning_model_description'] as String?,
      intentionsDescription: json['intentions_description'] as String?,
      notes: json['notes'] as String?,
      gradeLevels: (rawGradeLevels as List<dynamic>?)
              ?.map((item) => LessonGradeLevelModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

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
