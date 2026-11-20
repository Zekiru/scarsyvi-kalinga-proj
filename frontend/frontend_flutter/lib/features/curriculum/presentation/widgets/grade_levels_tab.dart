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
