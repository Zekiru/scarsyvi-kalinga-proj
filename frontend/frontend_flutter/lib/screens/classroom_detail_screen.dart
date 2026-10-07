import 'package:flutter/material.dart';
import '../models/classroom_model.dart';
import 'attendance_screen.dart';
import 'student_grade_batch_screen.dart';

class ClassroomDetailScreen extends StatelessWidget {
  final ClassroomModel classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(classroom.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Classroom Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School: ${classroom.schoolName}', style: const TextStyle(fontSize: 16)),
                    if (classroom.section != null) Text('Section: ${classroom.section}'),
                    Text('School Year: ${classroom.schoolYear}'),
                    if (classroom.lessonPlan != null) ...[
                      const Divider(),
                      Text('Linked Lesson Plan: ${classroom.lessonPlan!.lpTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Area: ${classroom.lessonPlan!.learningArea}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Log Attendance'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceScreen(classroom: classroom),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.grade_outlined),
                    label: const Text('Submit Grades'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentGradeBatchScreen(classroom: classroom),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Roster List
            Text(
              'Enrolled Students (${classroom.students.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classroom.students.length,
              itemBuilder: (context, index) {
                final student = classroom.students[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(student.gender),
                    ),
                    title: Text('${student.firstName} ${student.lastName}'),
                    subtitle: Text('LRN: ${student.lrn ?? "N/A"}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Attn: ${student.attendanceRate.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12)),
                        Text('Avg: ${student.gradeAvg.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
