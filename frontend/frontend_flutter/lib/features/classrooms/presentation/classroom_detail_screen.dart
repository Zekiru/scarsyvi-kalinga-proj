import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/presentation/lesson_plan_detail_screen.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../../forums/presentation/forum_threads_screen.dart';
import '../../forums/providers/forum_provider.dart';
import '../data/classroom_models.dart';
import '../data/classroom_repository.dart';
import '../providers/classroom_provider.dart';
import 'classrooms_screen.dart';

class ClassroomDetailScreen extends ConsumerWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
  });

  final String classroomId;

  void _openLinkedLessonPlan(BuildContext context, String lessonPlanId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPlanDetailScreen(lessonPlanId: lessonPlanId),
      ),
    );
  }

  Future<void> _openLinkedLessonPlanForum(
    BuildContext context,
    WidgetRef ref,
    Classroom classroom,
  ) async {
    final lpId = classroom.lessonPlanId;
    if (lpId == null || lpId.isEmpty) return;

    try {
      final forum = await ref
          .read(forumsProvider.notifier)
          .openOrCreateForumForLessonPlan(
            lessonPlanId: lpId,
            lessonPlanTitle: classroom.lessonPlanTitle,
          );
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ForumThreadsScreen(forum: forum),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open forum: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomAsync = ref.watch(classroomDetailProvider(classroomId));
    final currentUser = ref.watch(currentUserProvider);

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
        final isAdmin =
            currentUser != null && currentUser.role.apiValue == 'ADMIN';
        final canManage = classroom.isLocalDraft ||
            isAdmin ||
            (currentUser != null &&
                classroom.adviserId != null &&
                classroom.adviserId == currentUser.id);
        final hasLinkedLessonPlan = classroom.lessonPlanId != null &&
            classroom.lessonPlanId!.isNotEmpty;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(classroom.name),
                  if (classroom.section.isNotEmpty ||
                      classroom.schoolYear.isNotEmpty ||
                      classroom.lessonPlanTitle.isNotEmpty)
                    InkWell(
                      onTap: hasLinkedLessonPlan
                          ? () => _openLinkedLessonPlan(
                                context,
                                classroom.lessonPlanId!,
                              )
                          : null,
                      child: Text(
                        [
                          if (classroom.section.isNotEmpty)
                            'Section ${classroom.section}',
                          if (classroom.schoolYear.isNotEmpty)
                            'SY ${classroom.schoolYear}',
                          if (classroom.lessonPlanTitle.isNotEmpty)
                            'LP: ${classroom.lessonPlanTitle}',
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: hasLinkedLessonPlan
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              decoration: hasLinkedLessonPlan
                                  ? TextDecoration.underline
                                  : null,
                            ),
                      ),
                    ),
                ],
              ),
              actions: [
                if (hasLinkedLessonPlan) ...[
                  IconButton(
                    tooltip: 'Open Linked Lesson Plan',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => _openLinkedLessonPlan(
                      context,
                      classroom.lessonPlanId!,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Discuss Lesson Plan in Forum',
                    icon: const Icon(Icons.forum_outlined),
                    onPressed: () =>
                        _openLinkedLessonPlanForum(context, ref, classroom),
                  ),
                ],
                if (canManage) ...[
                  IconButton(
                    tooltip: 'Edit Classroom',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final updated = await showClassroomFormDialog(
                        context,
                        ref,
                        existing: classroom,
                      );
                      if (updated != null) {
                        ref.invalidate(classroomDetailProvider(classroomId));
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete Classroom',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Classroom?'),
                          content: Text(
                            'Delete "${classroom.name}"? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(classroomsProvider.notifier)
                            .deleteClassroom(classroom.id);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ],
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
                _RosterTab(classroom: classroom, canManage: canManage),
                _AttendanceTab(classroom: classroom, canManage: canManage),
                _GradebookTab(classroom: classroom, canManage: canManage),
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
  const _RosterTab({
    required this.classroom,
    required this.canManage,
  });

  final Classroom classroom;
  final bool canManage;

  @override
  ConsumerState<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends ConsumerState<_RosterTab> {
  String _ordering = 'last_name';

  void _refreshRoster() {
    ref.invalidate(classroomDetailProvider(widget.classroom.id));
    ref.invalidate(
      classroomRosterProvider(
        RosterQuery(
          classroomId: widget.classroom.id,
          ordering: _ordering,
        ),
      ),
    );
    ref.read(classroomsProvider.notifier).refresh();
  }

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
    GradeLevel? selectedLevel = levels.isNotEmpty
        ? levels.firstWhere(
            (g) => widget.classroom.gradeLevelIds.contains(g.id),
            orElse: () => levels.first,
          )
        : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add & Enroll New Student'),
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
                _refreshRoster();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save & Enroll'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEnrollExistingDialog() async {
    final repo = ref.read(classroomRepositoryProvider);
    List<Student> allStudents = const [];
    try {
      allStudents = await repo.fetchMasterStudents();
    } catch (_) {}

    if (!mounted) return;
    final enrolledIds = widget.classroom.students.map((s) => s.id).toSet();
    final candidates =
        allStudents.where((s) => !enrolledIds.contains(s.id)).toList();

    final selectedIds = <String>{};
    String filter = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final visible = filter.isEmpty
              ? candidates
              : candidates
                  .where(
                    (s) =>
                        s.fullName.toLowerCase().contains(filter) ||
                        s.lrn.toLowerCase().contains(filter),
                  )
                  .toList();

          return AlertDialog(
            title: const Text('Enroll Existing Students'),
            content: SizedBox(
              width: 440,
              height: 360,
              child: candidates.isEmpty
                  ? const Center(
                      child: Text(
                        'All directory students are already enrolled in this class.',
                      ),
                    )
                  : Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Filter by name or LRN...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) =>
                              setState(() => filter = val.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, idx) {
                              final stu = visible[idx];
                              final checked = selectedIds.contains(stu.id);
                              return CheckboxListTile(
                                value: checked,
                                title: Text(stu.formalName),
                                subtitle: Text(
                                  [
                                    if (stu.gradeLevelName.isNotEmpty)
                                      stu.gradeLevelName,
                                    if (stu.lrn.isNotEmpty) 'LRN: ${stu.lrn}',
                                  ].join(' • '),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedIds.add(stu.id);
                                    } else {
                                      selectedIds.remove(stu.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        final toEnroll = candidates
                            .where((s) => selectedIds.contains(s.id))
                            .toList();
                        await repo.enrollExistingStudents(
                          classroomId: widget.classroom.id,
                          studentsToEnroll: toEnroll,
                        );
                        ref.read(syncStatusProvider.notifier).refreshCounts();
                        _refreshRoster();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text('Enroll (${selectedIds.length})'),
              ),
            ],
          );
        },
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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                if (widget.canManage)
                  OutlinedButton.icon(
                    onPressed: _showEnrollExistingDialog,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Enroll Existing'),
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
                    child: Text(
                      'No students enrolled yet. Add or enroll a student to begin.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshRoster(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final stu = students[index];
                      final details = <String>[
                        if (stu.gradeLevelName.isNotEmpty) stu.gradeLevelName,
                        if (stu.lrn.isNotEmpty) 'LRN: ${stu.lrn}',
                        if (stu.gender.isNotEmpty) stu.gender,
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
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (stu.attendanceAverage != null)
                                Chip(
                                  label: Text(
                                    'Att: ${stu.attendanceAverage!.toStringAsFixed(0)}%',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (stu.isPendingSync)
                                const Chip(
                                  label: Text('Queued'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _showCreateStudentDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('New Student'),
            )
          : null,
    );
  }
}

// ==========================================
// 2. ATTENDANCE TAB (Batch + Individual Edit)
// ==========================================

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab({
    required this.classroom,
    required this.canManage,
  });

  final Classroom classroom;
  final bool canManage;

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  late String _selectedDate;
  final _remarksCtrl = TextEditingController();
  final Map<String, AttendanceStatus> _draftStatuses = {};
  final Map<String, String> _draftNotes = {};
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
        _draftNotes.clear();
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
        final notes = _draftNotes[stu.id] ?? existing?.notes ?? '';

        return StudentAttendanceEntry(
          studentId: stu.id,
          studentName: stu.fullName,
          status: status,
          notes: notes,
        );
      }).toList();

      await ref.read(classroomRepositoryProvider).recordAttendanceSession(
            classroomId: widget.classroom.id,
            date: _selectedDate,
            remarks: _remarksCtrl.text.isNotEmpty
                ? _remarksCtrl.text
                : (existingSession?.remarks ?? ''),
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
      _draftNotes.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance saved for $_selectedDate')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showIndividualAttendanceDialog({
    required Student student,
    required AttendanceStatus currentStatus,
    required String currentNotes,
    required AttendanceSession? existingSession,
  }) async {
    AttendanceStatus status = currentStatus;
    final notesCtrl = TextEditingController(text: currentNotes);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Attendance — ${student.formalName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date: $_selectedDate',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AttendanceStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: AttendanceStatus.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Excuse Reason (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                setState(() {
                  _draftStatuses[student.id] = status;
                  _draftNotes[student.id] = notesCtrl.text.trim();
                });
                Navigator.pop(ctx);
                await _saveSession(existingSession);
              },
              child: const Text('Save Student Attendance'),
            ),
          ],
        ),
      ),
    );
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
                  if (widget.canManage)
                    FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _saveSession(existingSession),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'Saving...' : 'Save All'),
                    ),
                ],
              ),
            ),
            if (widget.canManage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _remarksCtrl,
                  decoration: InputDecoration(
                    labelText: existingSession?.remarks.isNotEmpty == true
                        ? 'Session Remarks (${existingSession!.remarks})'
                        : 'Session Remarks (Optional)',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...students.map((stu) {
                    final savedRec = recordByStudent[stu.id];
                    final currentStatus = _draftStatuses[stu.id] ??
                        savedRec?.status ??
                        AttendanceStatus.present;
                    final currentNotes =
                        _draftNotes[stu.id] ?? savedRec?.notes ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    stu.formalName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (stu.gradeLevelName.isNotEmpty ||
                                      currentNotes.isNotEmpty)
                                    Text(
                                      [
                                        if (stu.gradeLevelName.isNotEmpty)
                                          stu.gradeLevelName,
                                        if (currentNotes.isNotEmpty)
                                          'Note: $currentNotes',
                                      ].join(' • '),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                    onSelectionChanged: widget.canManage
                                        ? (sel) {
                                            setState(() {
                                              _draftStatuses[stu.id] =
                                                  sel.first;
                                            });
                                          }
                                        : null,
                                  ),
                                  if (widget.canManage) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Edit individual status & note',
                                      icon: const Icon(Icons.edit_note),
                                      onPressed: () =>
                                          _showIndividualAttendanceDialog(
                                        student: stu,
                                        currentStatus: currentStatus,
                                        currentNotes: currentNotes,
                                        existingSession: existingSession,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (sessions.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text(
                      'Recorded Sessions (${sessions.length}) — Tap to Load & Edit',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...sessions.map(
                      (s) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_available),
                          title: Text(s.date),
                          subtitle: Text(
                            'Present: ${s.presentCount} • Late: ${s.lateCount} • Absent: ${s.absentCount} • Excused: ${s.excusedCount}'
                            '${s.remarks.isNotEmpty ? ' • ${s.remarks}' : ''}',
                          ),
                          trailing: s.isPendingSync
                              ? const Chip(label: Text('Queued'))
                              : const Icon(Icons.edit_calendar_outlined),
                          onTap: () {
                            setState(() {
                              _selectedDate = s.date;
                              _remarksCtrl.text = s.remarks;
                              _draftStatuses.clear();
                              _draftNotes.clear();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. GRADE-SPECIFIC GRADEBOOK TAB (Batch + Individual Edit)
// ==========================================

class _GradebookTab extends ConsumerWidget {
  const _GradebookTab({
    required this.classroom,
    required this.canManage,
  });

  final Classroom classroom;
  final bool canManage;

  List<Student> _eligibleStudentsForTask(LessonGrading task) {
    final targetGrade = task.gradeLevelName.trim().toLowerCase();
    if (targetGrade.isEmpty) return classroom.students;
    return classroom.students
        .where((s) => s.gradeLevelName.trim().toLowerCase() == targetGrade)
        .toList();
  }

  Future<void> _showSingleGradeEditDialog({
    required BuildContext context,
    required WidgetRef ref,
    required StudentGrade grade,
    required List<LessonGrading> gradingTasks,
  }) async {
    final matchingTask = gradingTasks
        .where((t) => t.id == grade.gradingTaskId)
        .firstOrNull;
    final maxScore = matchingTask?.maxScore.toDouble() ?? grade.maxScore;
    final scoreCtrl =
        TextEditingController(text: grade.score.toStringAsFixed(2));
    final feedbackCtrl = TextEditingController(text: grade.feedback);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Grade — ${grade.studentName.isNotEmpty ? grade.studentName : 'Student #${grade.studentId}'}',
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matchingTask != null &&
                          matchingTask.gradeLevelName.isNotEmpty
                      ? '${grade.gradingTaskName} (${matchingTask.gradeLevelName})'
                      : grade.gradingTaskName,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: scoreCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Score (Max: ${maxScore.toStringAsFixed(0)})',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed < 0 || parsed > maxScore) {
                      return 'Must be between 0 and ${maxScore.toStringAsFixed(0)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedbackCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Feedback (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final parsed = double.parse(scoreCtrl.text.trim());

              await ref.read(classroomRepositoryProvider).submitBatchGrades(
                classroomId: classroom.id,
                entries: [
                  StudentGrade(
                    id: grade.id,
                    studentId: grade.studentId,
                    studentName: grade.studentName,
                    gradingTaskId: grade.gradingTaskId,
                    gradingTaskName: grade.gradingTaskName,
                    score: parsed,
                    maxScore: maxScore,
                    feedback: feedbackCtrl.text,
                  ),
                ],
              );

              ref.read(syncStatusProvider.notifier).refreshCounts();
              final query = GradesQuery(
                classroomId: classroom.id,
                lessonPlanId: classroom.lessonPlanId,
                enrolledStudentIds:
                    classroom.students.map((s) => s.id).toSet(),
              );
              ref.invalidate(classroomGradesProvider(query));
              ref.invalidate(
                classroomRosterProvider(
                  RosterQuery(classroomId: classroom.id),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatchGradeDialog(
    BuildContext context,
    WidgetRef ref,
    List<StudentGrade> existingGrades,
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
            'Link a Lesson Plan with Grading Tasks to this classroom first (use Edit Classroom).',
          ),
        ),
      );
      return;
    }

    LessonGrading selectedTask = gradingTasks.first;

    Map<String, TextEditingController> buildScoreCtrls(LessonGrading task) {
      final eligible = _eligibleStudentsForTask(task);
      return {
        for (final s in eligible)
          s.id: TextEditingController(
            text: existingGrades
                    .where(
                      (g) => g.studentId == s.id && g.gradingTaskId == task.id,
                    )
                    .map((g) => g.score.toStringAsFixed(2))
                    .firstOrNull ??
                '',
          ),
      };
    }

    Map<String, TextEditingController> buildFeedbackCtrls(LessonGrading task) {
      final eligible = _eligibleStudentsForTask(task);
      return {
        for (final s in eligible)
          s.id: TextEditingController(
            text: existingGrades
                    .where(
                      (g) => g.studentId == s.id && g.gradingTaskId == task.id,
                    )
                    .map((g) => g.feedback)
                    .firstOrNull ??
                '',
          ),
      };
    }

    var scoreCtrls = buildScoreCtrls(selectedTask);
    var feedbackCtrls = buildFeedbackCtrls(selectedTask);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final eligibleStudents = _eligibleStudentsForTask(selectedTask);

          return AlertDialog(
            title: const Text('Submit Grade-Specific Scores'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<LessonGrading>(
                      initialValue: selectedTask,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grading Task (Filtered by Grade Level)',
                        border: OutlineInputBorder(),
                      ),
                      items: gradingTasks.map((t) {
                        final gradeTag = t.gradeLevelName.isNotEmpty
                            ? '[${t.gradeLevelName}] '
                            : '';
                        return DropdownMenuItem(
                          value: t,
                          child: Text(
                            '$gradeTag${t.taskName} (Max: ${t.maxScore}, Weight: ${t.gradeWeight.toStringAsFixed(0)}%)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedTask = val;
                            scoreCtrls = buildScoreCtrls(val);
                            feedbackCtrls = buildFeedbackCtrls(val);
                          });
                        }
                      },
                    ),
                    const Divider(height: 24),
                    if (eligibleStudents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No students enrolled in ${selectedTask.gradeLevelName.isNotEmpty ? selectedTask.gradeLevelName : 'this grade level'}. Only students in the matching grade level can receive grades for this task.',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...eligibleStudents.map(
                        (stu) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stu.formalName),
                                    if (stu.gradeLevelName.isNotEmpty)
                                      Text(
                                        stu.gradeLevelName,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: scoreCtrls[stu.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        'Score / ${selectedTask.maxScore}',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
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
                onPressed: eligibleStudents.isEmpty
                    ? null
                    : () async {
                        final entries = <StudentGrade>[];

                        for (final stu in eligibleStudents) {
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
                              gradingTaskName: selectedTask.taskName,
                              score: parsed,
                              maxScore: selectedTask.maxScore.toDouble(),
                              feedback: feedbackCtrls[stu.id]?.text ?? '',
                            ),
                          );
                        }

                        if (entries.isEmpty) return;

                        await ref
                            .read(classroomRepositoryProvider)
                            .submitBatchGrades(
                              classroomId: classroom.id,
                              entries: entries,
                            );

                        ref.read(syncStatusProvider.notifier).refreshCounts();
                        final query = GradesQuery(
                          classroomId: classroom.id,
                          lessonPlanId: classroom.lessonPlanId,
                          enrolledStudentIds:
                              classroom.students.map((s) => s.id).toSet(),
                        );
                        ref.invalidate(classroomGradesProvider(query));
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesQuery = GradesQuery(
      classroomId: classroom.id,
      lessonPlanId: classroom.lessonPlanId,
      enrolledStudentIds: classroom.students.map((s) => s.id).toSet(),
    );
    final gradesAsync = ref.watch(classroomGradesProvider(gradesQuery));
    final planAsync = (classroom.lessonPlanId != null &&
            classroom.lessonPlanId!.isNotEmpty)
        ? ref.watch(lessonPlanDetailProvider(classroom.lessonPlanId!))
        : null;

    final tasks = planAsync?.value?.gradings ?? const <LessonGrading>[];
    final taskById = {for (final t in tasks) t.id: t};
    final studentById = {for (final s in classroom.students) s.id: s};

    return Scaffold(
      body: gradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading grades: $err')),
        data: (grades) {
          final validGrades = grades.where((g) {
            final task = taskById[g.gradingTaskId];
            final stu = studentById[g.studentId];
            if (task != null &&
                stu != null &&
                task.gradeLevelName.trim().isNotEmpty &&
                stu.gradeLevelName.trim().isNotEmpty) {
              return task.gradeLevelName.trim().toLowerCase() ==
                  stu.gradeLevelName.trim().toLowerCase();
            }
            return true;
          }).toList();

          if (validGrades.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  classroom.lessonPlanId == null ||
                          classroom.lessonPlanId!.isEmpty
                      ? 'No Lesson Plan linked yet. Tap Edit Classroom to link a Lesson Plan with Grading Tasks.'
                      : 'No grades recorded yet. Tap + to submit task scores.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: validGrades.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final g = validGrades[index];
              final stu = studentById[g.studentId];
              final task = taskById[g.gradingTaskId];
              final stuLabel = g.studentName.isNotEmpty
                  ? g.studentName
                  : (stu?.fullName ?? 'Student #${g.studentId}');
              final gradeTag = (task != null && task.gradeLevelName.isNotEmpty)
                  ? ' (${task.gradeLevelName})'
                  : (stu != null && stu.gradeLevelName.isNotEmpty
                      ? ' (${stu.gradeLevelName})'
                      : '');
              final taskLabel = g.gradingTaskName.isNotEmpty
                  ? g.gradingTaskName
                  : (task?.taskName ?? 'Task #${g.gradingTaskId}');

              return Card(
                child: ListTile(
                  title: Text(
                    '$stuLabel$gradeTag — $taskLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Score: ${g.score.toStringAsFixed(2)} / ${g.maxScore.toStringAsFixed(0)}${g.feedback.isNotEmpty ? ' • ${g.feedback}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (g.isPendingSync) const Chip(label: Text('Queued')),
                      if (canManage)
                        IconButton(
                          tooltip: 'Edit individual grade',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showSingleGradeEditDialog(
                            context: context,
                            ref: ref,
                            grade: g,
                            gradingTasks: tasks,
                          ),
                        ),
                    ],
                  ),
                  onTap: canManage
                      ? () => _showSingleGradeEditDialog(
                            context: context,
                            ref: ref,
                            grade: g,
                            gradingTasks: tasks,
                          )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (canManage && classroom.students.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _showBatchGradeDialog(
                context,
                ref,
                gradesAsync.value ?? const [],
              ),
              icon: const Icon(Icons.add_chart),
              label: const Text('Submit Grades'),
            )
          : null,
    );
  }
}
