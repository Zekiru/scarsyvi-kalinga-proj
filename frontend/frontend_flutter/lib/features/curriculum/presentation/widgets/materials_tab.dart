import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class MaterialsTab extends ConsumerWidget {
  const MaterialsTab({super.key, required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: plan.materials.isEmpty
          ? const Center(child: Text('No instructional materials or references listed yet.'))
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
                          [m.materialType, if (m.resourceUrl.isNotEmpty) m.resourceUrl]
                              .join(' • '),
                        ),
                        if (m.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(m.notes),
                          ),
                      ],
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
    LessonGradeLevel? selectedGrade =
        plan.gradeLevels.isNotEmpty ? plan.gradeLevels.first : null;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Instructional Material / Reference'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (plan.gradeLevels.isNotEmpty) ...[
                  DropdownButtonFormField<LessonGradeLevel?>(
                    value: selectedGrade,
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
                    labelText: 'Material / Reference Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resource URL / Reference Code (Optional)',
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
                      lessonGradeLevelId: selectedGrade?.id,
                      gradeLevelName: selectedGrade?.gradeLevelName ?? '',
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
      ),
    );
  }
}
