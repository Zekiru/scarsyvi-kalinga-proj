import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class LessonFlowsTab extends ConsumerStatefulWidget {
  const LessonFlowsTab({
    super.key,
    required this.plan,
    required this.canEdit,
    this.canDelete = false,
  });

  final LessonPlan plan;
  final bool canEdit;
  final bool canDelete;

  @override
  ConsumerState<LessonFlowsTab> createState() => _LessonFlowsTabState();
}

class _LessonFlowsTabState extends ConsumerState<LessonFlowsTab> {
  String? _selectedLglFilter;

  @override
  Widget build(BuildContext context) {
    final allSteps = [...widget.plan.flows]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    final filteredSteps = _selectedLglFilter == null
        ? allSteps
        : allSteps
            .where((s) => s.lessonGradeLevelId == _selectedLglFilter)
            .toList();

    return Scaffold(
      body: allSteps.isEmpty
          ? const Center(child: Text('No lesson flow steps defined yet.'))
          : Column(
              children: [
                if (widget.plan.gradeLevels.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All Grades'),
                            selected: _selectedLglFilter == null,
                            onSelected: (_) =>
                                setState(() => _selectedLglFilter = null),
                          ),
                          ...widget.plan.gradeLevels.map(
                            (gl) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(
                                  gl.gradeLevelName.isNotEmpty
                                      ? gl.gradeLevelName
                                      : 'Grade ${gl.gradeLevelId}',
                                ),
                                selected: _selectedLglFilter == gl.id,
                                onSelected: (_) =>
                                    setState(() => _selectedLglFilter = gl.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 700 &&
                          widget.plan.gradeLevels.length >= 2 &&
                          _selectedLglFilter == null) {
                        return _MultiGradeFlowTable(
                          plan: widget.plan,
                          steps: filteredSteps,
                          canEdit: widget.canEdit,
                          canDelete: widget.canDelete,
                          onEdit: (step) => _flowDialog(
                            context,
                            ref,
                            allSteps.length + 1,
                            existing: step,
                          ),
                          onDelete: (step) => _confirmDelete(context, ref, step),
                        );
                      }
                      return _FlowCardList(
                        steps: filteredSteps,
                        canEdit: widget.canEdit,
                        canDelete: widget.canDelete,
                        onEdit: (step) => _flowDialog(
                          context,
                          ref,
                          allSteps.length + 1,
                          existing: step,
                        ),
                        onDelete: (step) => _confirmDelete(context, ref, step),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              onPressed: () =>
                  _flowDialog(context, ref, allSteps.length + 1),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonFlow step,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Flow Step?'),
        content: Text('Delete "${step.stage}" (${step.timeMinutes} min)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(curriculumRepositoryProvider).deleteLessonFlow(
          lessonPlanId: widget.plan.id,
          flowId: step.id,
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(widget.plan.id));
  }

  Future<void> _flowDialog(
    BuildContext context,
    WidgetRef ref,
    int nextOrder, {
    LessonFlow? existing,
  }) async {
    if (widget.plan.gradeLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach a Grade Level first before adding flow steps.'),
        ),
      );
      return;
    }

    LessonGradeLevel selectedGrade = existing != null
        ? widget.plan.gradeLevels.firstWhere(
            (g) => g.id == existing.lessonGradeLevelId,
            orElse: () => widget.plan.gradeLevels.first,
          )
        : widget.plan.gradeLevels.first;

    final stageCtrl = TextEditingController(text: existing?.stage ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final minsCtrl =
        TextEditingController(text: '${existing?.timeMinutes ?? 10}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final screenWidth = MediaQuery.sizeOf(ctx).width;
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
              existing == null
                  ? 'Add Lesson Flow Step'
                  : 'Edit Lesson Flow Step',
            ),
            content: SizedBox(
              width: screenWidth > 500 ? 440 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<LessonGradeLevel>(
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.plan.gradeLevels
                          .map(
                            (g) => DropdownMenuItem<LessonGradeLevel>(
                              value: g,
                              child: Text(
                                g.gradeLevelName.isNotEmpty
                                    ? g.gradeLevelName
                                    : 'Grade ${g.gradeLevelId}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedGrade = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stageCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Stage (e.g. Motivation, Instruction, Review)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Time (minutes)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Activity Description',
                        border: OutlineInputBorder(),
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
                  if (stageCtrl.text.trim().isEmpty) return;
                  final repo = ref.read(curriculumRepositoryProvider);
                  if (existing == null) {
                    await repo.addLessonFlow(
                      lessonPlanId: widget.plan.id,
                      lessonGradeLevelId: selectedGrade.id,
                      gradeLevelName: selectedGrade.gradeLevelName,
                      stepOrder: nextOrder,
                      stage: stageCtrl.text,
                      description: descCtrl.text,
                      timeMinutes: int.tryParse(minsCtrl.text) ?? 10,
                    );
                  } else {
                    await repo.updateLessonFlow(
                      lessonPlanId: widget.plan.id,
                      existing: existing,
                      lessonGradeLevelId: selectedGrade.id,
                      gradeLevelName: selectedGrade.gradeLevelName,
                      stage: stageCtrl.text,
                      description: descCtrl.text,
                      timeMinutes: int.tryParse(minsCtrl.text) ?? 10,
                    );
                  }
                  ref.read(syncStatusProvider.notifier).refreshCounts();
                  ref.invalidate(lessonPlanDetailProvider(widget.plan.id));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MultiGradeFlowTable extends StatelessWidget {
  const _MultiGradeFlowTable({
    required this.plan,
    required this.steps,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final LessonPlan plan;
  final List<LessonFlow> steps;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<LessonFlow> onEdit;
  final ValueChanged<LessonFlow> onDelete;

  @override
  Widget build(BuildContext context) {
    final grades = plan.gradeLevels;
    final hasActions = canEdit || canDelete;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            dataRowMaxHeight: double.infinity,
            columns: [
              const DataColumn(label: Text('Time')),
              const DataColumn(label: Text('Stage')),
              ...grades.map(
                (g) => DataColumn(
                  label: Text(
                    (g.gradeLevelName.isNotEmpty
                            ? g.gradeLevelName
                            : 'Grade ${g.gradeLevelId}')
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (hasActions) const DataColumn(label: Text('Actions')),
            ],
            rows: steps.map((step) {
              return DataRow(
                cells: [
                  DataCell(Text('${step.timeMinutes} min')),
                  DataCell(
                    SizedBox(
                      width: 140,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          step.stage,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  ...grades.map((g) {
                    final matches = step.lessonGradeLevelId == null ||
                        step.lessonGradeLevelId == g.id;
                    return DataCell(
                      SizedBox(
                        width: 260,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(matches ? step.description : '—'),
                        ),
                      ),
                    );
                  }),
                  if (hasActions)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              tooltip: 'Edit Step',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(step),
                            ),
                          if (canDelete)
                            IconButton(
                              tooltip: 'Delete Step',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => onDelete(step),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _FlowCardList extends StatelessWidget {
  const _FlowCardList({
    required this.steps,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LessonFlow> steps;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<LessonFlow> onEdit;
  final ValueChanged<LessonFlow> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final step = steps[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: Text(
                        '${step.timeMinutes}m',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.stage,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Edit Flow Step',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => onEdit(step),
                      ),
                    if (canDelete)
                      IconButton(
                        tooltip: 'Delete Flow Step',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: colors.error,
                        ),
                        onPressed: () => onDelete(step),
                      ),
                  ],
                ),
                if (step.gradeLevelName.isNotEmpty || step.isPendingSync) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (step.gradeLevelName.isNotEmpty)
                        Chip(
                          label: Text(step.gradeLevelName),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (step.isPendingSync)
                        const Chip(
                          label: Text('Queued'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                if (step.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(step.description),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
