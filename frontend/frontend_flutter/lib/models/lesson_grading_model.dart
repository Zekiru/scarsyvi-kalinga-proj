class LessonGradingModel {
  final int? lgId;
  final String taskName;
  final String? taskDescription;
  final double gradeWeight;
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
