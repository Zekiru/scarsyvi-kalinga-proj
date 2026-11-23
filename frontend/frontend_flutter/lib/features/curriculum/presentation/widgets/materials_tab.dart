import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class MaterialsTab extends ConsumerWidget {
  const MaterialsTab({
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
      body: plan.materials.isEmpty
          ? const Center(
              child: Text('No instructional materials or references listed yet.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plan.materials.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = plan.materials[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.attachment),
                    title: Text(m.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.gradeLevelName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Chip(
                              label: Text(m.gradeLevelName),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        Text(
                          [
                            m.materialType,
                            if (m.resourceUrl.isNotEmpty) m.resourceUrl,
                          ].join(' • '),
                        ),
                        if (m.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(m.notes),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.isPendingSync) const Chip(label: Text('Queued')),
                        if (canEdit)
                          IconButton(
                            tooltip: 'Edit Material',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                _materialDialog(context, ref, existing: m),
                          ),
                        if (canDelete)
                          IconButton(
                            tooltip: 'Delete Material',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _confirmDelete(context, ref, m),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _materialDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonMaterial material,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material?'),
        content: Text('Remove "${material.title}"?'),
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

    await ref.read(curriculumRepositoryProvider).deleteMaterial(
          lessonPlanId: plan.id,
          material: material,
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(plan.id));
  }

  Future<void> _materialDialog(
    BuildContext context,
    WidgetRef ref, {
    LessonMaterial? existing,
  }) async {
    LessonGradeLevel? selectedGrade;
    if (existing != null && existing.lessonGradeLevelId != null) {
      for (final g in plan.gradeLevels) {
        if (g.id == existing.lessonGradeLevelId) {
          selectedGrade = g;
          break;
        }
      }
    } else if (existing == null && plan.gradeLevels.isNotEmpty) {
      selectedGrade = plan.gradeLevels.first;
    }

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.resourceUrl ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Add Instructional Material / Reference'
                : 'Edit Instructional Material / Reference',
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (plan.gradeLevels.isNotEmpty) ...[
                  DropdownButtonFormField<LessonGradeLevel?>(
                    initialValue: selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade Level (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<LessonGradeLevel?>(
                        value: null,
                        child: Text('All Grade Levels'),
                      ),
                      ...plan.gradeLevels.map(
                        (g) => DropdownMenuItem<LessonGradeLevel?>(
                          value: g,
                          child: Text(
                            g.gradeLevelName.isNotEmpty
                                ? g.gradeLevelName
                                : 'Grade ${g.gradeLevelId}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => selectedGrade = val),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Material File Name / Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'File URL (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Usage Instructions / Description',
                    border: OutlineInputBorder(),
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
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final repo = ref.read(curriculumRepositoryProvider);
                if (existing == null) {
                  await repo.addMaterial(
                    lessonPlanId: plan.id,
                    lessonGradeLevelId: selectedGrade?.id,
                    gradeLevelName: selectedGrade?.gradeLevelName ?? '',
                    title: titleCtrl.text,
                    resourceUrl: urlCtrl.text,
                    notes: notesCtrl.text,
                  );
                } else {
                  await repo.updateMaterial(
                    lessonPlanId: plan.id,
                    existing: existing,
                    lessonGradeLevelId: selectedGrade?.id,
                    gradeLevelName: selectedGrade?.gradeLevelName ?? '',
                    title: titleCtrl.text,
                    resourceUrl: urlCtrl.text,
                    notes: notesCtrl.text,
                  );
                }
                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(lessonPlanDetailProvider(plan.id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
