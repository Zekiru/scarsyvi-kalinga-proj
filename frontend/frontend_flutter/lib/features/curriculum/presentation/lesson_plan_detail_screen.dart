import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/curriculum_models.dart';
import '../data/curriculum_repository.dart';
import '../providers/curriculum_provider.dart';

class LessonPlanDetailScreen extends ConsumerWidget {
  const LessonPlanDetailScreen({
    super.key,
    required this.lessonPlanId,
  });

  final String lessonPlanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(lessonPlanDetailProvider(lessonPlanId));
    final currentUser = ref.watch(currentUserProvider);

    return planAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Lesson Plan')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Lesson Plan')),
        body: Center(child: Text('Error loading lesson plan: $err')),
      ),
      data: (plan) {
        final isOwner =
            currentUser != null && plan.authorId == currentUser.id;
        final canEdit = isOwner || (currentUser?.canAdminister ?? false);
        final canReview = currentUser?.canModerate ?? false;

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(plan.title),
              actions: [
                if (!plan.isLocalDraft)
                  IconButton(
                    tooltip: 'Fork Lesson Plan',
                    icon: const Icon(Icons.fork_right),
                    onPressed: () async {
                      final forked = await ref
                          .read(lessonPlansProvider.notifier)
                          .forkLessonPlan(plan.serverId!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Forked "${forked.title}"')),
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => LessonPlanDetailScreen(
                              lessonPlanId: forked.id,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (canReview)
                  IconButton(
                    tooltip: plan.isApproved
                        ? 'Revoke Approval'
                        : 'Approve Lesson Plan',
                    icon: Icon(
                      plan.isApproved
                          ? Icons.verified
                          : Icons.verified_outlined,
                    ),
                    onPressed: () async {
                      await ref
                          .read(curriculumRepositoryProvider)
                          .setLessonPlanApproval(
                            lessonPlanId: plan.id,
                            isApproved: !plan.isApproved,
                          );
                      ref.read(syncStatusProvider.notifier).refreshCounts();
                      ref.invalidate(lessonPlanDetailProvider(lessonPlanId));
                      ref.read(lessonPlansProvider.notifier).refresh();
                    },
                  ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Grades'),
                  Tab(text: 'Lesson Flow'),
                  Tab(text: 'Grading'),
                  Tab(text: 'Materials'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (plan.description.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    child: Text(plan.description),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _GradeLevelsTab(plan: plan, canEdit: canEdit),
                      _LessonFlowsTab(plan: plan, canEdit: canEdit),
                      _LessonGradingsTab(plan: plan, canEdit: canEdit),
                      _MaterialsTab(plan: plan, canEdit: canEdit),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradeLevelsTab extends ConsumerWidget {
  const _GradeLevelsTab({required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.gradeLevels.isEmpty
          ? const Center(child: Text('No target grade levels attached yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plan.gradeLevels.length,
              itemBuilder: (context, i) {
                final item = plan.gradeLevels[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      item.gradeLevelName.isNotEmpty
                          ? item.gradeLevelName
                          : 'Grade Level #${item.gradeLevelId}',
                    ),
                    subtitle: item.specificObjectives.isNotEmpty
                        ? Text(item.specificObjectives)
                        : null,
                    trailing: item.isPendingSync
                        ? const Chip(label: Text('Queued'))
                        : null,
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
    final objCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Attach Grade Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<GradeLevel>(
                initialValue: selected,
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
                controller: objCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Grade-Specific Objectives',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
                      specificObjectives: objCtrl.text,
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

class _LessonFlowsTab extends ConsumerWidget {
  const _LessonFlowsTab({required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...plan.flows]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return Scaffold(
      body: sorted.isEmpty
          ? const Center(child: Text('No lesson flow steps defined yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final step = sorted[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${step.stepOrder}')),
                    title: Text('${step.phaseName} (${step.durationMinutes} min)'),
                    subtitle: Text(step.activityDescription),
                    trailing: step.isPendingSync
                        ? const Chip(label: Text('Queued'))
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _addFlowDialog(context, ref, sorted.length + 1),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addFlowDialog(
    BuildContext context,
    WidgetRef ref,
    int nextOrder,
  ) async {
    final phaseCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '15');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Lesson Flow Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phaseCtrl,
              decoration: const InputDecoration(
                labelText: 'Phase (e.g. Motivation, Activity, Assessment)',
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
            const SizedBox(height: 12),
            TextField(
              controller: minsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (phaseCtrl.text.trim().isEmpty) return;
              await ref.read(curriculumRepositoryProvider).addLessonFlow(
                    lessonPlanId: plan.id,
                    stepOrder: nextOrder,
                    phaseName: phaseCtrl.text,
                    activityDescription: descCtrl.text,
                    durationMinutes: int.tryParse(minsCtrl.text) ?? 15,
                  );
              ref.read(syncStatusProvider.notifier).refreshCounts();
              ref.invalidate(lessonPlanDetailProvider(plan.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _LessonGradingsTab extends ConsumerWidget {
  const _LessonGradingsTab({required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.gradings.isEmpty
          ? const Center(child: Text('No grading criteria defined yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plan.gradings.length,
              itemBuilder: (context, i) {
                final g = plan.gradings[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      '${g.criteriaName} (${g.weightPercentage.toStringAsFixed(0)}%)',
                    ),
                    subtitle:
                        g.rubricNotes.isNotEmpty ? Text(g.rubricNotes) : null,
                    trailing: g.isPendingSync
                        ? const Chip(label: Text('Queued'))
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _addGradingDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addGradingDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '30');
    final notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Grading Criterion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Criterion Name (e.g. Performance Task)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (%)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rubric Notes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(curriculumRepositoryProvider).addLessonGrading(
                    lessonPlanId: plan.id,
                    criteriaName: nameCtrl.text,
                    weightPercentage: double.tryParse(weightCtrl.text) ?? 0,
                    rubricNotes: notesCtrl.text,
                  );
              ref.read(syncStatusProvider.notifier).refreshCounts();
              ref.invalidate(lessonPlanDetailProvider(plan.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MaterialsTab extends ConsumerWidget {
  const _MaterialsTab({required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.materials.isEmpty
          ? const Center(child: Text('No teaching materials listed yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plan.materials.length,
              itemBuilder: (context, i) {
                final m = plan.materials[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.attachment),
                    title: Text(m.title),
                    subtitle: Text(
                      [m.materialType, if (m.resourceUrl.isNotEmpty) m.resourceUrl]
                          .join(' • '),
                    ),
                    trailing: m.isPendingSync
                        ? const Chip(label: Text('Queued'))
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _addMaterialDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addMaterialDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Teaching Material'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Material Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Resource URL / Reference (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Preparation Notes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await ref.read(curriculumRepositoryProvider).addMaterial(
                    lessonPlanId: plan.id,
                    title: titleCtrl.text,
                    resourceUrl: urlCtrl.text,
                    notes: notesCtrl.text,
                  );
              ref.read(syncStatusProvider.notifier).refreshCounts();
              ref.invalidate(lessonPlanDetailProvider(plan.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
