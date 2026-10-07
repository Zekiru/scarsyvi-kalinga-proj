import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classroom_model.dart';
import '../models/student_model.dart';
import '../providers/app_providers.dart';
import 'attendance_screen.dart';
import 'student_grade_batch_screen.dart';

class ClassroomDetailScreen extends ConsumerStatefulWidget {
  final ClassroomModel classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  ConsumerState<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends ConsumerState<ClassroomDetailScreen> {
  List<StudentModel> _localStudents = [];
  StudentSortBy _currentSortBy = StudentSortBy.nameAsc;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _localStudents = List<StudentModel>.from(widget.classroom.students);
  }

  @override
  void didUpdateWidget(covariant ClassroomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasUnsavedChanges && oldWidget.classroom != widget.classroom) {
      _localStudents = List<StudentModel>.from(widget.classroom.students);
    }
  }

  List<StudentModel> get _sortedStudents {
    if (_localStudents.isEmpty) return [];
    final sortedList = List<StudentModel>.from(_localStudents);
    sortedList.sort((a, b) => a.compareTo(b, _currentSortBy));
    return sortedList;
  }

  String _formatPercentage(double value) {
    // If backend returns a decimal (0.0 to 1.0), scale it to 0-100%
    final normalized = (value <= 1.0 && value > 0.0) ? value * 100 : value;
    return '${normalized.toStringAsFixed(1)}%';
  }

  void _openStudentDialog({StudentModel? existingStudent}) {
    final firstNameController = TextEditingController(text: existingStudent?.firstName ?? '');
    final lastNameController = TextEditingController(text: existingStudent?.lastName ?? '');
    final lrnController = TextEditingController(text: existingStudent?.lrn ?? '');

    final availableGradeLevels = widget.classroom.gradeLevels;
    int? glId = existingStudent?.glId;

    if (glId != null && !availableGradeLevels.any((gl) => gl.glId == glId)) {
      glId = availableGradeLevels.isNotEmpty ? availableGradeLevels.first.glId : null;
    } else if (glId == null && availableGradeLevels.isNotEmpty) {
      glId = availableGradeLevels.first.glId;
    }

    String gender = (existingStudent?.gender.isNotEmpty == true) ? existingStudent!.gender : 'M';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingStudent == null ? 'Add Student' : 'Edit Student'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    TextField(
                      controller: lrnController,
                      decoration: const InputDecoration(labelText: 'LRN (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Male')),
                        DropdownMenuItem(value: 'F', child: Text('Female')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => gender = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (availableGradeLevels.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: glId,
                        decoration: const InputDecoration(labelText: 'Grade Level'),
                        items: availableGradeLevels.map((gl) {
                          return DropdownMenuItem<int>(
                            value: gl.glId,
                            child: Text(gl.gradeLevelName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => glId = val);
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
                      return;
                    }

                    final updatedStudent = StudentModel(
                      studentId: existingStudent?.studentId,
                      glId: glId ?? 1,
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      gender: gender,
                      lrn: lrnController.text.trim().isEmpty ? null : lrnController.text.trim(),
                      attendanceRate: existingStudent?.attendanceRate ?? 0.0,
                      gradeAvg: existingStudent?.gradeAvg ?? 0.0,
                    );

                    setState(() {
                      if (existingStudent != null) {
                        final targetIndex = _localStudents.indexWhere(
                          (s) => (s.studentId != null && s.studentId == existingStudent.studentId) ||
                                 (s.firstName == existingStudent.firstName && s.lastName == existingStudent.lastName),
                        );
                        if (targetIndex != -1) {
                          _localStudents[targetIndex] = updatedStudent;
                        } else {
                          _localStudents.add(updatedStudent);
                        }
                      } else {
                        _localStudents.add(updatedStudent);
                      }
                      _hasUnsavedChanges = true;
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStudent(StudentModel student) {
    setState(() {
      _localStudents.removeWhere((s) =>
          (s.studentId != null && s.studentId == student.studentId) ||
          (s.firstName == student.firstName && s.lastName == student.lastName));
      _hasUnsavedChanges = true;
    });
  }

  void _navigateToAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(
          classroom: widget.classroom,
        ),
      ),
    );
  }

  void _navigateToGrading() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeBatchScreen(
          classroom: widget.classroom,
        ),
      ),
    );
  }

  Future<void> _saveClassroomChanges() async {
    setState(() => _isSaving = true);

    final payload = ClassroomModel(
      classroomId: widget.classroom.classroomId,
      name: widget.classroom.name,
      schoolName: widget.classroom.schoolName,
      section: widget.classroom.section,
      schoolYear: widget.classroom.schoolYear,
      isActive: widget.classroom.isActive,
      adviser: widget.classroom.adviser,
      gradeLevelIds: widget.classroom.gradeLevelIds.isNotEmpty
          ? widget.classroom.gradeLevelIds
          : widget.classroom.gradeLevels.map((g) => g.glId).toList(),
      lessonPlanId: widget.classroom.lessonPlanId ?? widget.classroom.lessonPlan?.lpId,
      students: _localStudents,
    );

    try {
      await ref.read(apiServiceProvider).updateClassroom(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classroom roster saved successfully!')),
        );
        ref.read(classroomsProvider.notifier).refresh();
        setState(() => _hasUnsavedChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update classroom roster: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedStudents = _sortedStudents;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom.name),
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveClassroomChanges,
              tooltip: 'Save Roster Changes',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.classroom.schoolName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('Section: ${widget.classroom.section ?? "N/A"} | School Year: ${widget.classroom.schoolYear}'),
                    if (widget.classroom.lessonPlan != null) ...[
                      const SizedBox(height: 8),
                      Text('Linked Lesson Plan: ${widget.classroom.lessonPlan!.lpTitle}',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Students (${_localStudents.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                PopupMenuButton<StudentSortBy>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort Roster',
                  onSelected: (sortBy) {
                    setState(() => _currentSortBy = sortBy);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: StudentSortBy.nameAsc,
                      child: Text('Name (A-Z)'),
                    ),
                    PopupMenuItem(
                      value: StudentSortBy.nameDesc,
                      child: Text('Name (Z-A)'),
                    ),
                    PopupMenuItem(
                      value: StudentSortBy.gradeAvgDesc,
                      child: Text('Grade Average (High to Low)'),
                    ),
                    PopupMenuItem(
                      value: StudentSortBy.attendanceRateDesc,
                      child: Text('Attendance Rate (High to Low)'),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openStudentDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Student'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            displayedStudents.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No students currently enrolled.')),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedStudents.length,
                    itemBuilder: (context, index) {
                      final student = displayedStudents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(student.sortableName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'LRN: ${student.lrn ?? "N/A"} | Att: ${_formatPercentage(student.attendanceRate)} | Grade Avg: ${_formatPercentage(student.gradeAvg)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.calendar_today_outlined, color: Colors.teal),
                                tooltip: 'Attendance',
                                onPressed: _navigateToAttendance,
                              ),
                              IconButton(
                                icon: const Icon(Icons.grade_outlined, color: Colors.orange),
                                tooltip: 'Grading',
                                onPressed: _navigateToGrading,
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Details',
                                onPressed: () => _openStudentDialog(existingStudent: student),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete Student',
                                onPressed: () => _deleteStudent(student),
                              ),
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
