import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class GradeLevelsTab extends ConsumerWidget {
  const GradeLevelsTab({super.key, required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.gradeLevels.isEmpty
          ? const Center(child: Text('No target grade levels attached yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plan.gradeLevels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = plan.gradeLevels[i];
                final title = item.gradeLevelName.isNotEmpty
                    ? item.gradeLevelName
                    : 'Grade Level #${item.gradeLevelId}';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            if (item.flows.isNotEmpty)
                              Chip(
                                label: Text('${item.flows.length} flow steps'),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (item.gradingTasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Chip(
                                  label:
                                      Text('${item.gradingTasks.length} tasks'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            if (item.isPendingSync)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Chip(label: Text('Queued')),
                              ),
                          ],
                        ),
                        if (item.contentStandard.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _LabeledBlock('Content Standard (I)', item.contentStandard),
                        ],
                        if (item.performanceStandard.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Performance Standard (I)', item.performanceStandard),
                        ],
                        if (item.learningCompetencies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Competencies & Codes (I)', item.learningCompetencies),
                        ],
                        if (item.learningObjectives.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Learning Objectives (I)', item.learningObjectives),
                        ],
                        if (item.learnerContext.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Learner Context (L)', item.learnerContext),
                        ],
                        if (item.reflectionQuestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _LabeledBlock('Reflection Questions (W)', item.reflectionQuestions),
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
              onPressed: () => _addGradeDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addGradeDialog(BuildContext context, WidgetRef ref) async {
    final levels = await ref.read(gradeLevelsProvider.future);
    if (!context.mounted || levels.isEmpty) return;

    GradeLevel selected = levels.first;
    final contentCtrl = TextEditingController();
    final perfCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final objCtrl = TextEditingController();
    final contextCtrl = TextEditingController();
    final reflectCtrl = TextEditingController();
    final remCtrl = TextEditingController();
    final enrichCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Attach Grade Level & Standards'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<GradeLevel>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Grade Level',
                      border: OutlineInputBorder(),
                    ),
                    items: levels
                        .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
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
                      labelText: 'Content Standard (i_content_standard)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: perfCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Performance Standard (i_performance_standard)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: compCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Competencies & Codes (i_competencies_codes)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: objCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Learning Objectives (i_objectives)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contextCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Learner Context (l_context)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reflectCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reflection Questions (w_reflection_questions)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remediation (re_remediation)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: enrichCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Enrichment (re_enrichment)',
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
                await ref
                    .read(curriculumRepositoryProvider)
                    .addLessonGradeLevel(
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
                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(lessonPlanDetailProvider(plan.id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
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
