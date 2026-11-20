import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

class LessonFlowsTab extends ConsumerWidget {
  const LessonFlowsTab({super.key, required this.plan, required this.canEdit});

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
