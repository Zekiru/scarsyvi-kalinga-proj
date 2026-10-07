import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter/models/student_model.dart';
import '../models/classroom_model.dart';
import '../models/attendance_model.dart';
import '../providers/app_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final ClassroomModel classroom;
  final StudentModel? student;

  const AttendanceScreen({
    super.key, required this.classroom, this.student,
  });

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final Map<int, String> _statuses = {};
  final Map<int, String> _notes = {};
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var student in widget.classroom.students) {
      if (student.studentId != null) {
        _statuses[student.studentId!] = 'PRESENT';
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final records = _statuses.entries.map((e) {
      return StudentAttendanceRecord(
        studentId: e.key,
        status: e.value,
        notes: _notes[e.key],
      );
    }).toList();

    final session = AttendanceSessionModel(
      date: dateStr,
      remarks: _remarksController.text,
      records: records,
    );

    try {
      await ref.read(apiServiceProvider).submitAttendance(widget.classroom.classroomId!, session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!')),
        );
        ref.read(classroomsProvider.notifier).refresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance: ${widget.classroom.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                labelText: 'Session Remarks (Optional)',
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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text('${student.firstName} ${student.lastName}'),
                    subtitle: DropdownButton<String>(
                      value: _statuses[id],
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'PRESENT', child: Text('Present')),
                        DropdownMenuItem(value: 'ABSENT', child: Text('Absent')),
                        DropdownMenuItem(value: 'LATE', child: Text('Late')),
                        DropdownMenuItem(value: 'EXCUSED', child: Text('Excused')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statuses[id] = val);
                      },
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
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Save Session Attendance'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
