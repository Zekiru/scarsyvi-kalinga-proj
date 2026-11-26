import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class GradeLevelsTab extends ConsumerWidget {
  const GradeLevelsTab({
    super.key,
    required this.plan,
    required this.canEdit,
    this.canDelete = false,
  });

  final LessonPlan plan;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.gradeLevels.isEmpty
          ? const Center(child: Text('No target grade levels attached yet.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: plan.gradeLevels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = plan.gradeLevels[i];
                final title = item.gradeLevelName.isNotEmpty
                    ? item.gradeLevelName
                    : 'Grade Level #${item.gradeLevelId}';

                final hasChips = item.flows.isNotEmpty ||
                    item.gradingTasks.isNotEmpty ||
                    item.isPendingSync;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (canEdit)
                              IconButton(
                                tooltip: 'Edit Grade Level & Standards',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _gradeDialog(
                                  context,
                                  ref,
                                  existing: item,
                                ),
                              ),
                            if (canDelete)
                              IconButton(
                                tooltip: 'Delete Grade Level',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, ref, item, title),
                              ),
                          ],
                        ),
                        if (hasChips) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.flows.isNotEmpty)
                                Chip(
                                  label:
                                      Text('${item.flows.length} flow steps'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (item.gradingTasks.isNotEmpty)
                                Chip(
                                  label:
                                      Text('${item.gradingTasks.length} tasks'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (item.isPendingSync)
                                const Chip(
                                  label: Text('Queued'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                        if (item.contentStandard.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _LabeledBlock(
                            'Content Standard (I)',
                            item.contentStandard,
                          ),
                        ],
                        if (item.performanceStandard.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock(
                            'Performance Standard (I)',
                            item.performanceStandard,
                          ),
                        ],
                        if (item.learningCompetencies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock(
                            'Competencies & Codes (I)',
                            item.learningCompetencies,
                          ),
                        ],
                        if (item.learningObjectives.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock(
                            'Learning Objectives (I)',
                            item.learningObjectives,
                          ),
                        ],
                        if (item.learnerContext.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock(
                            'Learner Context (L)',
                            item.learnerContext,
                          ),
                        ],
                        if (item.reflectionQuestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock(
                            'Reflection Questions (W)',
                            item.reflectionQuestions,
                          ),
                        ],
                        if (item.remediation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Remediation (RE)', item.remediation),
                        ],
                        if (item.enrichment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Enrichment (RE)', item.enrichment),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _gradeDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonGradeLevel item,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Grade Level?'),
        content: Text(
          'Remove "$title" and its standards from this lesson plan?',
        ),
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

    await ref.read(curriculumRepositoryProvider).deleteLessonGradeLevel(
          lessonPlanId: plan.id,
          lessonGradeLevelId: item.id,
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(plan.id));
  }

  Future<void> _gradeDialog(
    BuildContext context,
    WidgetRef ref, {
    LessonGradeLevel? existing,
  }) async {
    final levels = await ref.read(gradeLevelsProvider.future);
    if (!context.mounted || levels.isEmpty) return;

    GradeLevel selected = existing != null
        ? levels.firstWhere(
            (g) => g.id == existing.gradeLevelId,
            orElse: () => levels.first,
          )
        : levels.first;

    final contentCtrl =
        TextEditingController(text: existing?.contentStandard ?? '');
    final perfCtrl =
        TextEditingController(text: existing?.performanceStandard ?? '');
    final compCtrl =
        TextEditingController(text: existing?.learningCompetencies ?? '');
    final objCtrl =
        TextEditingController(text: existing?.learningObjectives ?? '');
    final contextCtrl =
        TextEditingController(text: existing?.learnerContext ?? '');
    final reflectCtrl =
        TextEditingController(text: existing?.reflectionQuestions ?? '');
    final remCtrl = TextEditingController(text: existing?.remediation ?? '');
    final enrichCtrl = TextEditingController(text: existing?.enrichment ?? '');

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
                  ? 'Attach Grade Level & Standards'
                  : 'Edit Grade Level & Standards',
            ),
            content: SizedBox(
              width: screenWidth > 540 ? 480 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<GradeLevel>(
                      initialValue: selected,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                      ),
                      items: levels
                          .map(
                            (g) =>
                                DropdownMenuItem(value: g, child: Text(g.name)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selected = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Content Standard (I)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: perfCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Performance Standard (I)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: compCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Competencies & Codes (I)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: objCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Learning Objectives (I)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contextCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Learner Context (L)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reflectCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reflection Questions (W)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remediation (RE)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: enrichCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Enrichment (RE)',
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
                  final repo = ref.read(curriculumRepositoryProvider);
                  if (existing == null) {
                    await repo.addLessonGradeLevel(
                      lessonPlanId: plan.id,
                      gradeLevelId: selected.id,
                      gradeLevelName: selected.name,
                      contentStandard: contentCtrl.text,
                      performanceStandard: perfCtrl.text,
                      learningCompetencies: compCtrl.text,
                      specificObjectives: objCtrl.text,
                      learnerContext: contextCtrl.text,
                      reflectionQuestions: reflectCtrl.text,
                      remediation: remCtrl.text,
                      enrichment: enrichCtrl.text,
                    );
                  } else {
                    await repo.updateLessonGradeLevel(
                      lessonPlanId: plan.id,
                      existing: existing,
                      gradeLevelId: selected.id,
                      gradeLevelName: selected.name,
                      contentStandard: contentCtrl.text,
                      performanceStandard: perfCtrl.text,
                      learningCompetencies: compCtrl.text,
                      specificObjectives: objCtrl.text,
                      learnerContext: contextCtrl.text,
                      reflectionQuestions: reflectCtrl.text,
                      remediation: remCtrl.text,
                      enrichment: enrichCtrl.text,
                    );
                  }
                  ref.read(syncStatusProvider.notifier).refreshCounts();
                  ref.invalidate(lessonPlanDetailProvider(plan.id));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(text),
      ],
    );
  }
}
