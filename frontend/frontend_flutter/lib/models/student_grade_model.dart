class StudentGradeItem {
  final int studentId;
  final int gradingTaskId;
  final double score;
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

class StudentGradeBatchPayload {
  final List<StudentGradeItem> grades;

  StudentGradeBatchPayload({required this.grades});

  Map<String, dynamic> toJson() {
    return {
      'grades': grades.map((g) => g.toJson()).toList(),
    };
  }
}

class StudentGradeReadModel {
  final int id;
  final int studentId;
  final String? studentName;
  final int gradingTaskId;
  final String? gradingTaskTitle;
  final double score;
  final String? feedback;
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
