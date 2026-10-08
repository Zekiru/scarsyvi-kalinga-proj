import 'package:hive/hive.dart';

part 'lesson_flow_model.g.dart';

@HiveType(typeId: 5)
class LessonFlowModel extends HiveObject {
  @HiveField(0)
  final int? lfId;

  @HiveField(1)
  final int timeMinutes;

  @HiveField(2)
  final String stage;

  @HiveField(3)
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
