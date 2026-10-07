import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter/models/student_model.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';
import '../models/lesson_grading_model.dart';
import '../models/student_grade_model.dart';
import '../providers/app_providers.dart';

class StudentGradeBatchScreen extends ConsumerStatefulWidget {
  final ClassroomModel classroom;
  final StudentModel? student;

  const StudentGradeBatchScreen({
    super.key, required this.classroom, this.student,
    });

  @override
  ConsumerState<StudentGradeBatchScreen> createState() => _StudentGradeBatchScreenState();
}

class _StudentGradeBatchScreenState extends ConsumerState<StudentGradeBatchScreen> {
  int? _selectedTaskId;
  int? _selectedTaskGradeLevelId;
  Future<LessonPlanModel?>? _lessonPlanFuture;
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

    final lpId = widget.classroom.lessonPlan?.lpId;
    if (lpId != null) {
      _lessonPlanFuture = _loadLinkedLessonPlan(lpId);
    }
  }

  Future<LessonPlanModel?> _loadLinkedLessonPlan(int lpId) async {
    final plans = await ref.read(apiServiceProvider).fetchLessonPlans();
    try {
      return plans.firstWhere((plan) => plan.lpId == lpId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitGrades() async {
    if (_selectedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grading task from the dropdown')),
      );
      return;
    }

    final eligibleStudents = widget.classroom.students.where((student) {
      return _selectedTaskGradeLevelId == null || student.glId == _selectedTaskGradeLevelId;
    }).toList();

    if (eligibleStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible students found for this grade level task.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final gradeItems = eligibleStudents
        .where((s) => s.studentId != null)
        .map((student) {
      final controller = _scoreControllers[student.studentId!];
      return StudentGradeItem(
        studentId: student.studentId!,
        gradingTaskId: _selectedTaskId!,
        score: double.tryParse(controller?.text ?? '0.00') ?? 0.0,
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
    final filteredStudents = widget.classroom.students.where((student) {
      if (_selectedTaskGradeLevelId == null) return true;
      return student.glId == _selectedTaskGradeLevelId;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Grade Entry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _lessonPlanFuture == null
                ? const Card(
                    color: Colors.amber,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('No lesson plan linked to this classroom.'),
                    ),
                  )
                : FutureBuilder<LessonPlanModel?>(
                    future: _lessonPlanFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Failed to load tasks: ${snapshot.error}');
                      }

                      final plan = snapshot.data;
                      final taskItems = <Map<String, dynamic>>[];
                      if (plan != null) {
                        for (var gl in plan.gradeLevels) {
                          for (var task in gl.gradingTasks) {
                            taskItems.add({
                              'glId': gl.glId,
                              'glName': gl.gradeLevelName,
                              'task': task,
                            });
                          }
                        }
                      }

                      if (taskItems.isEmpty) {
                        return const Text('No grading tasks found in linked lesson plan.');
                      }

                      return DropdownButtonFormField<int>(
                        value: _selectedTaskId,
                        decoration: const InputDecoration(
                          labelText: 'Select Grading Task',
                          border: OutlineInputBorder(),
                        ),
                        items: taskItems.map((item) {
                          final task = item['task'] as LessonGradingModel;
                          final glName = item['glName'] as String?;
                          return DropdownMenuItem<int>(
                            value: task.lgId,
                            child: Text(
                              '[${glName ?? "GL ${item['glId']}"}] ${task.taskName} (Max: ${task.maxScore})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selectedItem = taskItems.firstWhere(
                            (item) => (item['task'] as LessonGradingModel).lgId == val,
                          );
                          setState(() {
                            _selectedTaskId = val;
                            _selectedTaskGradeLevelId = selectedItem['glId'] as int;
                          });
                        },
                      );
                    },
                  ),
          ),
          if (_selectedTaskGradeLevelId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${filteredStudents.length} student(s) matching selected task grade level.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ),
          Expanded(
            child: filteredStudents.isEmpty
                ? const Center(
                    child: Text('No students match the selected task grade level.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final id = student.studentId!;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0), // Increased row spacing
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${student.firstName} ${student.lastName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('Grade Level ID: ${student.glId}'),
                            trailing: SizedBox(
                              width: 110,
                              child: TextField(
                                controller: _scoreControllers[id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Score',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
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
