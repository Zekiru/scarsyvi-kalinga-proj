import 'package:hive/hive.dart';

part 'lesson_grading_model.g.dart';

@HiveType(typeId: 8)
class LessonGradingModel extends HiveObject {
  @HiveField(0)
  final int? lgId;

  @HiveField(1)
  final String taskName;

  @HiveField(2)
  final String? taskDescription;

  @HiveField(3)
  final double gradeWeight;

  @HiveField(4)
  final int maxScore;

  LessonGradingModel({
    this.lgId,
    required this.taskName,
    this.taskDescription,
    required this.gradeWeight,
    required this.maxScore,
  });

  factory LessonGradingModel.fromJson(Map<String, dynamic> json) {
    return LessonGradingModel(
      lgId: json['lg_id'] as int?,
      taskName: json['task_name'] as String,
      taskDescription: json['task_description'] as String?,
      gradeWeight: (json['grade_weight'] is String)
          ? double.parse(json['grade_weight'] as String)
          : (json['grade_weight'] as num).toDouble(),
      maxScore: json['max_score'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lgId != null) 'lg_id': lgId,
      'task_name': taskName,
      'task_description': taskDescription,
      'grade_weight': gradeWeight.toStringAsFixed(2),
      'max_score': maxScore,
    };
  }
}
