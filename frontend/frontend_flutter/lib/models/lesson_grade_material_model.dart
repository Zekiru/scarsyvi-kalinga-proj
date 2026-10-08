import 'package:hive/hive.dart';
import 'material_model.dart';

part 'lesson_grade_material_model.g.dart';

@HiveType(typeId: 7)
class LessonGradeMaterialModel extends HiveObject {
  @HiveField(0)
  final MaterialModel material;

  @HiveField(1)
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
