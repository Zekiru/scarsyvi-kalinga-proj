import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

Future<LessonPlan?> showLessonPlanFormDialog(
  BuildContext context,
  WidgetRef ref, {
  LessonPlan? existingPlan,
}) {
  return showDialog<LessonPlan>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LessonPlanWizardDialog(existingPlan: existingPlan),
  );
}

class _LessonPlanWizardDialog extends ConsumerStatefulWidget {
  const _LessonPlanWizardDialog({this.existingPlan});

  final LessonPlan? existingPlan;

  @override
  ConsumerState<_LessonPlanWizardDialog> createState() =>
      _LessonPlanWizardDialogState();
}

class _LessonPlanWizardDialogState
    extends ConsumerState<_LessonPlanWizardDialog> {
  int _step = 0;
  bool _saving = false;
  LessonPlan? _activePlan;
  LessonGradeLevel? _createdGradeLevel;

  final _baseFormKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _langCtrl;
  late final TextEditingController _demoCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _intentionsCtrl;
  late final TextEditingController _notesCtrl;

  GradeLevel? _selectedGrade;
  final _iContentCtrl = TextEditingController();
  final _iPerfCtrl = TextEditingController();
  final _iCompCtrl = TextEditingController();
  final _iObjCtrl = TextEditingController();
  final _lContextCtrl = TextEditingController();
  final _wReflectCtrl = TextEditingController();
  final _reRemCtrl = TextEditingController();
  final _reEnrichCtrl = TextEditingController();

  final _stageCtrl = TextEditingController();
  final _flowDescCtrl = TextEditingController();
  final _minsCtrl = TextEditingController(text: '10');

  final _taskNameCtrl = TextEditingController();
  final _taskDescCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '40');
  final _maxScoreCtrl = TextEditingController(text: '10');

  final _matTitleCtrl = TextEditingController();
  final _matUrlCtrl = TextEditingController();
  final _matNotesCtrl = TextEditingController();

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    _activePlan = p;

    String resolve(String primary, List<String> fallbackKeys) {
      if (primary.trim().isNotEmpty) return primary;
      if (p == null) return '';
      return p.firstNonEmpty(fallbackKeys);
    }

    _titleCtrl = TextEditingController(
      text: resolve(p?.title ?? '', ['lp_title', 'title']),
    );
    _subjectCtrl = TextEditingController(
      text: resolve(p?.subject ?? '', ['learning_area', 'subject']),
    );
    _langCtrl = TextEditingController(
      text: resolve(p?.primaryLanguage ?? '', ['primary_language']).isNotEmpty
          ? resolve(p?.primaryLanguage ?? '', ['primary_language'])
          : 'English',
    );
    _demoCtrl = TextEditingController(
      text: resolve(p?.suggestedDemographic ?? '', ['suggested_demographic']),
    );
    _modelCtrl = TextEditingController(
      text: resolve(
        p?.learningModelDescription ?? '',
        ['learning_model_description', 'multigrade_model'],
      ),
    );
    _intentionsCtrl = TextEditingController(
      text: resolve(
        p?.intentionsDescription ?? '',
        ['intentions_description', 'shared_sub_theme'],
      ),
    );
    _notesCtrl = TextEditingController(
      text: resolve(p?.notes ?? '', ['notes', 'notes_for_next_session']),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _langCtrl.dispose();
    _demoCtrl.dispose();
    _modelCtrl.dispose();
    _intentionsCtrl.dispose();
    _notesCtrl.dispose();
    _iContentCtrl.dispose();
    _iPerfCtrl.dispose();
    _iCompCtrl.dispose();
    _iObjCtrl.dispose();
    _lContextCtrl.dispose();
    _wReflectCtrl.dispose();
    _reRemCtrl.dispose();
    _reEnrichCtrl.dispose();
    _stageCtrl.dispose();
    _flowDescCtrl.dispose();
    _minsCtrl.dispose();
    _taskNameCtrl.dispose();
    _taskDescCtrl.dispose();
    _weightCtrl.dispose();
    _maxScoreCtrl.dispose();
    _matTitleCtrl.dispose();
    _matUrlCtrl.dispose();
    _matNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBasePlan() async {
    if (!(_baseFormKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      if (_isEditing) {
        final updated = await ref
            .read(lessonPlansProvider.notifier)
            .updateLessonPlan(
              lessonPlanId: widget.existingPlan!.id,
              title: _titleCtrl.text,
              subject: _subjectCtrl.text,
              primaryLanguage: _langCtrl.text,
              suggestedDemographic: _demoCtrl.text,
              multigradeModel: _modelCtrl.text,
              sharedSubTheme: _intentionsCtrl.text,
              notesForNextSession: _notesCtrl.text,
            );
        if (mounted) Navigator.pop(context, updated);
        return;
      }

      final created = await ref
          .read(lessonPlansProvider.notifier)
          .createLessonPlan(
            title: _titleCtrl.text,
            subject: _subjectCtrl.text,
            primaryLanguage: _langCtrl.text,
            suggestedDemographic: _demoCtrl.text,
            multigradeModel: _modelCtrl.text,
            sharedSubTheme: _intentionsCtrl.text,
          );

      final finalPlan = _notesCtrl.text.trim().isNotEmpty
          ? await ref.read(lessonPlansProvider.notifier).updateLessonPlan(
                lessonPlanId: created.id,
                title: _titleCtrl.text,
                subject: _subjectCtrl.text,
                primaryLanguage: _langCtrl.text,
                suggestedDemographic: _demoCtrl.text,
                multigradeModel: _modelCtrl.text,
                sharedSubTheme: _intentionsCtrl.text,
                notesForNextSession: _notesCtrl.text,
              )
          : created;

      if (mounted) {
        setState(() {
          _activePlan = finalPlan;
          _step = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save lesson plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitGradeLevel() async {
    final plan = _activePlan;
    final grade = _selectedGrade;
    if (plan == null || grade == null) return;

    setState(() => _saving = true);
    try {
      final createdLgl =
          await ref.read(curriculumRepositoryProvider).addLessonGradeLevel(
                lessonPlanId: plan.id,
                gradeLevelId: grade.id,
                gradeLevelName: grade.name,
                contentStandard: _iContentCtrl.text,
                performanceStandard: _iPerfCtrl.text,
                learningCompetencies: _iCompCtrl.text,
                specificObjectives: _iObjCtrl.text,
                learnerContext: _lContextCtrl.text,
                reflectionQuestions: _wReflectCtrl.text,
                remediation: _reRemCtrl.text,
                enrichment: _reEnrichCtrl.text,
              );
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(lessonPlanDetailProvider(plan.id));

      if (mounted) {
        setState(() {
          _createdGradeLevel = createdLgl;
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add grade level: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitFlow() async {
    final plan = _activePlan;
    final lgl = _createdGradeLevel;
    if (plan == null || lgl == null) return;

    if (_stageCtrl.text.trim().isEmpty) {
      setState(() => _step = 3);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(curriculumRepositoryProvider).addLessonFlow(
            lessonPlanId: plan.id,
            lessonGradeLevelId: lgl.id,
            gradeLevelName: lgl.gradeLevelName,
            stepOrder: 1,
            stage: _stageCtrl.text,
            description: _flowDescCtrl.text,
            timeMinutes: int.tryParse(_minsCtrl.text) ?? 10,
          );
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(lessonPlanDetailProvider(plan.id));
      if (mounted) setState(() => _step = 3);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add lesson flow: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitGrading() async {
    final plan = _activePlan;
    final lgl = _createdGradeLevel;
    if (plan == null || lgl == null) return;

    if (_taskNameCtrl.text.trim().isEmpty) {
      setState(() => _step = 4);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(curriculumRepositoryProvider).addLessonGrading(
            lessonPlanId: plan.id,
            lessonGradeLevelId: lgl.id,
            gradeLevelName: lgl.gradeLevelName,
            taskName: _taskNameCtrl.text,
            taskDescription: _taskDescCtrl.text,
            gradeWeight: double.tryParse(_weightCtrl.text) ?? 40,
            maxScore: int.tryParse(_maxScoreCtrl.text) ?? 10,
          );
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(lessonPlanDetailProvider(plan.id));
      if (mounted) setState(() => _step = 4);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add grading task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitMaterial() async {
    final plan = _activePlan;
    if (plan == null) return;

    if (_matTitleCtrl.text.trim().isEmpty) {
      Navigator.pop(context, plan);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(curriculumRepositoryProvider).addMaterial(
            lessonPlanId: plan.id,
            lessonGradeLevelId: _createdGradeLevel?.id,
            gradeLevelName: _createdGradeLevel?.gradeLevelName ?? '',
            title: _matTitleCtrl.text,
            resourceUrl: _matUrlCtrl.text,
            notes: _matNotesCtrl.text,
          );
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(lessonPlanDetailProvider(plan.id));
      if (mounted) Navigator.pop(context, plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add material: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dialogTitle {
    if (_isEditing) return 'Edit Lesson Plan';
    return switch (_step) {
      0 => 'Step 1 of 5: Lesson Plan Details',
      1 => 'Step 2 of 5: Grade Level & Standards',
      2 => 'Step 3 of 5: Initial Lesson Flow',
      3 => 'Step 4 of 5: Initial Grading Task',
      _ => 'Step 5 of 5: Instructional Material',
    };
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 460;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_dialogTitle),
      content: SizedBox(
        width: screenWidth > 580 ? 520 : double.maxFinite,
        child: SingleChildScrollView(
          child: switch (_step) {
            0 => _buildBasePlanStep(isMobile),
            1 => _buildGradeLevelStep(),
            2 => _buildFlowStep(),
            3 => _buildGradingStep(),
            _ => _buildMaterialStep(),
          },
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: _buildActions(),
    );
  }

  List<Widget> _buildActions() {
    if (_isEditing) {
      return [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submitBasePlan,
          child: Text(_saving ? 'Saving...' : 'Save Changes'),
        ),
      ];
    }

    if (_step == 0) {
      return [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submitBasePlan,
          child: Text(_saving ? 'Creating...' : 'Create & Continue'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, _activePlan),
        child: const Text('Finish'),
      ),
      if (_step < 4)
        OutlinedButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                    if (_step == 1 && _createdGradeLevel == null) {
                      _step = 4;
                    } else {
                      _step++;
                    }
                  }),
          child: const Text('Skip'),
        ),
      FilledButton(
        onPressed: _saving
            ? null
            : switch (_step) {
                1 => _submitGradeLevel,
                2 => _submitFlow,
                3 => _submitGrading,
                _ => _submitMaterial,
              },
        child: Text(
          _saving
              ? 'Saving...'
              : (_step == 4 ? 'Save & Finish' : 'Save & Next'),
        ),
      ),
    ];
  }

  Widget _buildBasePlanStep(bool isMobile) {
    return Form(
      key: _baseFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Lesson Plan Title *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Learning Area (e.g. Mathematics, Filipino) *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            TextFormField(
              controller: _langCtrl,
              decoration: const InputDecoration(
                labelText: 'Primary Language',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _demoCtrl,
              decoration: const InputDecoration(
                labelText: 'Suggested Demographic',
                border: OutlineInputBorder(),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _langCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primary Language',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _demoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Suggested Demographic',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Learning Model Description (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _intentionsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Intentions Description (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeLevelStep() {
    final levelsAsync = ref.watch(gradeLevelsProvider);
    return levelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Could not load grade levels: $err'),
      data: (levels) {
        if (levels.isEmpty) {
          return const Text('No grade levels configured on the server.');
        }
        _selectedGrade ??= levels.first;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<GradeLevel>(
              initialValue: _selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Target Grade Level',
                border: OutlineInputBorder(),
              ),
              items: levels
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGrade = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iContentCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Content Standard (I)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iPerfCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Performance Standard (I)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iCompCtrl,
              decoration: const InputDecoration(
                labelText: 'Competencies & Codes (I)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iObjCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Learning Objectives (I)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lContextCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Learner Context (L)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wReflectCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reflection Questions (W)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reRemCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remediation (RE)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reEnrichCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Enrichment (RE)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlowStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Adding initial flow step for ${_createdGradeLevel?.gradeLevelName ?? 'Grade Level'}:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _stageCtrl,
          decoration: const InputDecoration(
            labelText: 'Stage (e.g. Introduction, Instruction)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minsCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Time (minutes)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _flowDescCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Activity Description',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildGradingStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Adding initial grading task for ${_createdGradeLevel?.gradeLevelName ?? 'Grade Level'}:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taskNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Task Name (e.g. Tens and Ones Exit Ticket)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (%)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxScoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Score',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taskDescCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Task Description',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _matTitleCtrl,
          decoration: const InputDecoration(
            labelText: 'Material File Name / Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _matUrlCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'File URL (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _matNotesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Usage Instructions / Description (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
