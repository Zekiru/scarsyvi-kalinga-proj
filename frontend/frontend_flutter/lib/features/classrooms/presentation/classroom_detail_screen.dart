import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../data/classroom_models.dart';
import '../data/classroom_repository.dart';
import '../providers/classroom_provider.dart';

class ClassroomDetailScreen extends ConsumerWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
  });

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomAsync = ref.watch(classroomDetailProvider(classroomId));

    return classroomAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Classroom')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Classroom')),
        body: Center(child: Text('Failed to load classroom: $err')),
      ),
      data: (classroom) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(classroom.name),
                  if (classroom.section.isNotEmpty ||
                      classroom.schoolYear.isNotEmpty)
                    Text(
                      [
                        if (classroom.section.isNotEmpty)
                          'Section ${classroom.section}',
                        if (classroom.schoolYear.isNotEmpty)
                          'SY ${classroom.schoolYear}',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people_outline), text: 'Roster'),
                  Tab(icon: Icon(Icons.fact_check_outlined), text: 'Attendance'),
                  Tab(icon: Icon(Icons.grading_outlined), text: 'Gradebook'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RosterTab(classroom: classroom),
                _AttendanceTab(classroom: classroom),
                _GradebookTab(classroom: classroom),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 1. STUDENT ROSTER & ANALYTICS TAB
// ==========================================

class _RosterTab extends ConsumerStatefulWidget {
  const _RosterTab({required this.classroom});

  final Classroom classroom;

  @override
  ConsumerState<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends ConsumerState<_RosterTab> {
  String _ordering = 'last_name';

  Future<void> _showCreateStudentDialog() async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final lrnCtrl = TextEditingController();
    String gender = 'M';
    final formKey = GlobalKey<FormState>();

    List<GradeLevel> levels = const [];
    try {
      levels = await ref.read(gradeLevelsProvider.future);
    } catch (_) {}

    if (!mounted) return;
    GradeLevel? selectedLevel = levels.isNotEmpty ? levels.first : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add & Enroll Student'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstCtrl,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: lastCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => gender = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: lrnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'LRN (12-digit Learner Ref)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (levels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GradeLevel>(
                      initialValue: selectedLevel,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                      ),
                      items: levels
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedLevel = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await ref
                    .read(classroomRepositoryProvider)
                    .createAndEnrollStudent(
                      classroomId: widget.classroom.id,
                      firstName: firstCtrl.text,
                      lastName: lastCtrl.text,
                      gender: gender,
                      lrn: lrnCtrl.text,
                      gradeLevelId: selectedLevel?.id,
                      gradeLevelName: selectedLevel?.name ?? '',
                    );
                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(classroomDetailProvider(widget.classroom.id));
                ref.invalidate(
                  classroomRosterProvider(
                    RosterQuery(
                      classroomId: widget.classroom.id,
                      ordering: _ordering,
                    ),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save & Enroll'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = RosterQuery(
      classroomId: widget.classroom.id,
      ordering: _ordering,
    );
    final rosterAsync = ref.watch(classroomRosterProvider(query));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text('Sort by: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _ordering,
                  items: const [
                    DropdownMenuItem(
                      value: 'last_name',
                      child: Text('Last Name (A–Z)'),
                    ),
                    DropdownMenuItem(
                      value: '-grade_average',
                      child: Text('Highest Grade Average'),
                    ),
                    DropdownMenuItem(
                      value: 'grade_average',
                      child: Text('Lowest Grade Average'),
                    ),
                    DropdownMenuItem(
                      value: '-attendance_average',
                      child: Text('Highest Attendance %'),
                    ),
                    DropdownMenuItem(
                      value: 'attendance_average',
                      child: Text('Lowest Attendance %'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _ordering = val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: rosterAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading roster: $err')),
              data: (students) {
                if (students.isEmpty) {
                  return const Center(
                    child:
                        Text('No students enrolled yet. Tap + to add a student.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final stu = students[index];
                    final details = <String>[
                      if (stu.lrn.isNotEmpty) 'LRN: ${stu.lrn}',
                      if (stu.gradeLevelName.isNotEmpty) stu.gradeLevelName,
                    ];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            stu.firstName.isNotEmpty
                                ? stu.firstName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(stu.formalName),
                        subtitle: details.isNotEmpty
                            ? Text(details.join(' • '))
                            : null,
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            if (stu.gradeAverage != null)
                              Chip(
                                label: Text(
                                  'Grade: ${stu.gradeAverage!.toStringAsFixed(1)}%',
                                ),
                              ),
                            if (stu.attendanceAverage != null)
                              Chip(
                                label: Text(
                                  'Att: ${stu.attendanceAverage!.toStringAsFixed(0)}%',
                                ),
                              ),
                            if (stu.isPendingSync)
                              const Chip(label: Text('Queued')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStudentDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Student'),
      ),
    );
  }
}

// ==========================================
// 2. BATCH ATTENDANCE TAB (`record-attendance/`)
// ==========================================

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab({required this.classroom});

  final Classroom classroom;

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  late String _selectedDate;
  final _remarksCtrl = TextEditingController();
  final Map<String, AttendanceStatus> _draftStatuses = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _formatDate(DateTime.now());
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = _formatDate(picked);
        _draftStatuses.clear();
      });
    }
  }

  Future<void> _saveSession(AttendanceSession? existingSession) async {
    if (widget.classroom.students.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final existingMap = {
        for (final r
            in existingSession?.records ?? const <StudentAttendanceEntry>[])
          r.studentId: r,
      };

      final entries = widget.classroom.students.map((stu) {
        final existing = existingMap[stu.id];
        final status = _draftStatuses[stu.id] ??
            existing?.status ??
            AttendanceStatus.present;

        return StudentAttendanceEntry(
          studentId: stu.id,
          studentName: stu.fullName,
          status: status,
          notes: existing?.notes ?? '',
        );
      }).toList();

      await ref.read(classroomRepositoryProvider).recordAttendanceSession(
            classroomId: widget.classroom.id,
            date: _selectedDate,
            remarks: _remarksCtrl.text,
            records: entries,
          );

      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(classroomAttendanceSessionsProvider(widget.classroom.id));
      ref.invalidate(
        classroomRosterProvider(
          RosterQuery(classroomId: widget.classroom.id),
        ),
      );
      _draftStatuses.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance recorded for $_selectedDate')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = [...widget.classroom.students]
      ..sort((a, b) => a.formalName.compareTo(b.formalName));

    if (students.isEmpty) {
      return const Center(
        child:
            Text('Enroll students in the Roster tab before taking attendance.'),
      );
    }

    final sessionsAsync =
        ref.watch(classroomAttendanceSessionsProvider(widget.classroom.id));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading sessions: $err')),
      data: (sessions) {
        final existingSession =
            sessions.where((s) => s.date == _selectedDate).firstOrNull;
        final recordByStudent = {
          for (final r
              in existingSession?.records ?? const <StudentAttendanceEntry>[])
            r.studentId: r,
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('Date: $_selectedDate'),
                  ),
                  if (existingSession?.isPendingSync ?? false) ...[
                    const SizedBox(width: 8),
                    const Chip(label: Text('Queued')),
                  ],
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        _isSaving ? null : () => _saveSession(existingSession),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save Session'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session Remarks (Optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final stu = students[index];
                  final savedRec = recordByStudent[stu.id];
                  final currentStatus = _draftStatuses[stu.id] ??
                      savedRec?.status ??
                      AttendanceStatus.present;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            stu.formalName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SegmentedButton<AttendanceStatus>(
                            segments: const [
                              ButtonSegment(
                                value: AttendanceStatus.present,
                                label: Text('Present'),
                              ),
                              ButtonSegment(
                                value: AttendanceStatus.late,
                                label: Text('Late'),
                              ),
                              ButtonSegment(
                                value: AttendanceStatus.absent,
                                label: Text('Absent'),
                              ),
                              ButtonSegment(
                                value: AttendanceStatus.excused,
                                label: Text('Excused'),
                              ),
                            ],
                            selected: {currentStatus},
                            onSelectionChanged: (sel) {
                              setState(() {
                                _draftStatuses[stu.id] = sel.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. GRADEBOOK TAB (`submit-grades/` tied to `LessonGrading`)
// ==========================================

class _GradebookTab extends ConsumerWidget {
  const _GradebookTab({required this.classroom});

  final Classroom classroom;

  Future<void> _showBatchGradeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (classroom.students.isEmpty) return;

    List<LessonGrading> gradingTasks = const [];
    if (classroom.lessonPlanId != null && classroom.lessonPlanId!.isNotEmpty) {
      try {
        final plan = await ref
            .read(lessonPlanDetailProvider(classroom.lessonPlanId!).future);
        gradingTasks = plan.gradings;
      } catch (_) {}
    }

    if (!context.mounted) return;

    if (gradingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link a Lesson Plan with Grading Criteria to this classroom first.',
          ),
        ),
      );
      return;
    }

    LessonGrading selectedTask = gradingTasks.first;
    final scoreCtrls = <String, TextEditingController>{
      for (final s in classroom.students) s.id: TextEditingController(),
    };
    final feedbackCtrls = <String, TextEditingController>{
      for (final s in classroom.students) s.id: TextEditingController(),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Submit Batch Grades'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<LessonGrading>(
                    initialValue: selectedTask,
                    decoration: const InputDecoration(
                      labelText: 'Grading Task (from Lesson Plan)',
                      border: OutlineInputBorder(),
                    ),
                    items: gradingTasks
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              '${t.criteriaName} (${t.weightPercentage.toStringAsFixed(0)}%)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedTask = val);
                    },
                  ),
                  const Divider(height: 24),
                  ...classroom.students.map(
                    (stu) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(stu.formalName),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: scoreCtrls[stu.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Score',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: feedbackCtrls[stu.id],
                              decoration: const InputDecoration(
                                labelText: 'Feedback (Optional)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final entries = <StudentGrade>[];

                for (final stu in classroom.students) {
                  final raw = scoreCtrls[stu.id]?.text.trim() ?? '';
                  if (raw.isEmpty) continue;
                  final parsed = double.tryParse(raw);
                  if (parsed == null) continue;

                  entries.add(
                    StudentGrade(
                      id: '',
                      studentId: stu.id,
                      studentName: stu.fullName,
                      gradingTaskId: selectedTask.id,
                      gradingTaskName: selectedTask.criteriaName,
                      score: parsed,
                      feedback: feedbackCtrls[stu.id]?.text ?? '',
                    ),
                  );
                }

                if (entries.isEmpty) return;

                await ref.read(classroomRepositoryProvider).submitBatchGrades(
                      classroomId: classroom.id,
                      entries: entries,
                    );

                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(classroomGradesProvider(classroom.id));
                ref.invalidate(
                  classroomRosterProvider(
                    RosterQuery(classroomId: classroom.id),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Submit Grades'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(classroomGradesProvider(classroom.id));

    return Scaffold(
      body: gradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading grades: $err')),
        data: (grades) {
          if (grades.isEmpty) {
            return const Center(
              child:
                  Text('No grades recorded yet. Tap + to submit task scores.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: grades.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final g = grades[index];
              final stuLabel = g.studentName.isNotEmpty
                  ? g.studentName
                  : 'Student #${g.studentId}';
              final taskLabel = g.gradingTaskName.isNotEmpty
                  ? g.gradingTaskName
                  : 'Task #${g.gradingTaskId}';

              return Card(
                child: ListTile(
                  title: Text(
                    '$stuLabel — $taskLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Score: ${g.score.toStringAsFixed(2)}${g.feedback.isNotEmpty ? ' • ${g.feedback}' : ''}',
                  ),
                  trailing: g.isPendingSync
                      ? const Chip(label: Text('Queued'))
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: classroom.students.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showBatchGradeDialog(context, ref),
              icon: const Icon(Icons.add_chart),
              label: const Text('Submit Grades'),
            ),
    );
  }
}
