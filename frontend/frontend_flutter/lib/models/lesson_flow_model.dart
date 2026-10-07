class LessonFlowModel {
  final int? lfId;
  final int timeMinutes;
  final String stage;
  final String description;

  LessonFlowModel({
    this.lfId,
    required this.timeMinutes,
    required this.stage,
    required this.description,
  });

  factory LessonFlowModel.fromJson(Map<String, dynamic> json) {
    return LessonFlowModel(
      lfId: json['lf_id'] as int?,
      timeMinutes: json['time_minutes'] as int,
      stage: json['stage'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lfId != null) 'lf_id': lfId,
      'time_minutes': timeMinutes,
      'stage': stage,
      'description': description,
    };
  }
}
