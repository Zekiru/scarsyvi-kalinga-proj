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
