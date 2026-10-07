import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classroom_model.dart';
import '../models/student_grade_model.dart';
import '../providers/app_providers.dart';

class StudentGradeBatchScreen extends ConsumerStatefulWidget {
  final ClassroomModel classroom;

  const StudentGradeBatchScreen({super.key, required this.classroom});

  @override
  ConsumerState<StudentGradeBatchScreen> createState() => _StudentGradeBatchScreenState();
}

class _StudentGradeBatchScreenState extends ConsumerState<StudentGradeBatchScreen> {
  final TextEditingController _taskIdController = TextEditingController();
  final Map<int, TextEditingController> _scoreControllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var student in widget.classroom.students) {
      if (student.studentId != null) {
        _scoreControllers[student.studentId!] = TextEditingController(text: '0.00');
      }
    }
  }

  @override
  void dispose() {
    _taskIdController.dispose();
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitGrades() async {
    final taskId = int.tryParse(_taskIdController.text);
    if (taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Grading Task ID')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final gradeItems = _scoreControllers.entries.map((e) {
      return StudentGradeItem(
        studentId: e.key,
        gradingTaskId: taskId,
        score: double.tryParse(e.value.text) ?? 0.0,
      );
    }).toList();

    final payload = StudentGradeBatchPayload(grades: gradeItems);

    try {
      await ref.read(apiServiceProvider).submitGrades(widget.classroom.classroomId!, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grades submitted successfully!')),
        );
        ref.read(classroomsProvider.notifier).refresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit grades: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Grade Entry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _taskIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lesson Grading Task ID',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.classroom.students.length,
              itemBuilder: (context, index) {
                final student = widget.classroom.students[index];
                final id = student.studentId!;
                return ListTile(
                  title: Text('${student.firstName} ${student.lastName}'),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _scoreControllers[id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Score',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitGrades,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit All Grades'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
