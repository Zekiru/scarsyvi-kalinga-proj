import 'material_model.dart';

class LessonGradeMaterialModel {
  final MaterialModel material;
  final String? usageInstructions;

  LessonGradeMaterialModel({
    required this.material,
    this.usageInstructions,
  });

  factory LessonGradeMaterialModel.fromJson(Map<String, dynamic> json) {
    return LessonGradeMaterialModel(
      material: MaterialModel.fromJson(json['material'] as Map<String, dynamic>),
      usageInstructions: json['usage_instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material.toJson(),
      'usage_instructions': usageInstructions,
    };
  }
}
