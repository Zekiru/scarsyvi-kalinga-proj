import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class LessonGradingsTab extends ConsumerWidget {
  const LessonGradingsTab({super.key, required this.plan, required this.canEdit});

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
