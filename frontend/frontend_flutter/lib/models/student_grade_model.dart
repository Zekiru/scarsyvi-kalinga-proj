import 'package:hive/hive.dart';

part 'student_grade_model.g.dart';

@HiveType(typeId: 11)
class StudentGradeItem extends HiveObject {
  @HiveField(0)
  final int studentId;

  @HiveField(1)
  final int gradingTaskId;

  @HiveField(2)
  final double score;

  @HiveField(3)
  final String? feedback;

  StudentGradeItem({
    required this.studentId,
    required this.gradingTaskId,
    required this.score,
    this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'grading_task_id': gradingTaskId,
      'score': score.toStringAsFixed(2),
      'feedback': feedback ?? '',
    };
  }
}

@HiveType(typeId: 12)
class StudentGradeBatchPayload extends HiveObject {
  @HiveField(0)
  final List<StudentGradeItem> grades;

  StudentGradeBatchPayload({required this.grades});

  Map<String, dynamic> toJson() {
    return {
      'grades': grades.map((g) => g.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 13)
class StudentGradeReadModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int studentId;

  @HiveField(2)
  final String? studentName;

  @HiveField(3)
  final int gradingTaskId;

  @HiveField(4)
  final String? gradingTaskTitle;

  @HiveField(5)
  final double score;

  @HiveField(6)
  final String? feedback;

  @HiveField(7)
  final String? submittedAt;

  StudentGradeReadModel({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.gradingTaskId,
    this.gradingTaskTitle,
    required this.score,
    this.feedback,
    this.submittedAt,
  });

  factory StudentGradeReadModel.fromJson(Map<String, dynamic> json) {
    return StudentGradeReadModel(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      gradingTaskId: json['grading_task_id'] as int,
      gradingTaskTitle: json['grading_task_title'] as String?,
      score: (json['score'] is String)
          ? double.parse(json['score'] as String)
          : (json['score'] as num).toDouble(),
      feedback: json['feedback'] as String?,
      submittedAt: json['submitted_at'] as String?,
    );
  }
}
