import 'package:flutter/material.dart';
import '../models/classroom_model.dart';
import '../models/student_model.dart';
import 'attendance_screen.dart';
import 'student_grade_batch_screen.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final ClassroomModel classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  StudentSortBy _selectedSort = StudentSortBy.nameAsc;

  @override
  Widget build(BuildContext context) {
    final sortedStudents = widget.classroom.getSortedStudents(_selectedSort);

    return Scaffold(
      appBar: AppBar(title: Text(widget.classroom.name)),
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
                    Text('School: ${widget.classroom.schoolName}', style: const TextStyle(fontSize: 16)),
                    if (widget.classroom.section != null) Text('Section: ${widget.classroom.section}'),
                    Text('School Year: ${widget.classroom.schoolYear}'),
                    if (widget.classroom.lessonPlan != null) ...[
                      const Divider(),
                      Text('Linked Lesson Plan: ${widget.classroom.lessonPlan!.lpTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Area: ${widget.classroom.lessonPlan!.learningArea}'),
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
                          builder: (_) => AttendanceScreen(classroom: widget.classroom),
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
                          builder: (_) => StudentGradeBatchScreen(classroom: widget.classroom),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Roster Header with Sorting Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enrolled Students (${sortedStudents.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<StudentSortBy>(
                  value: _selectedSort,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort),
                  onChanged: (StudentSortBy? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSort = newValue;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: StudentSortBy.nameAsc,
                      child: Text('Name (A–Z)'),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.nameDesc,
                      child: Text('Name (Z–A)'),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.gradeAvgDesc,
                      child: Text('Highest Grade'),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.attendanceRateDesc,
                      child: Text('Highest Attendance'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Roster List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedStudents.length,
              itemBuilder: (context, index) {
                final student = sortedStudents[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(student.gender),
                    ),
                    title: Text(student.fullName),
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
