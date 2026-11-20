import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/curriculum_models.dart';
import '../../providers/curriculum_provider.dart';

Future<LessonPlan?> showCreateLessonPlanDialog(
  BuildContext context,
  WidgetRef ref,
) {
  final titleCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();
  final langCtrl = TextEditingController(text: 'English');
  final demoCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isPublic = true;

  return showDialog<LessonPlan>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('New Lesson Plan'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Learning Area (e.g. Science, Mathematics)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: langCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Primary Language (e.g. English, Tagalog / Filipino)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: demoCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Suggested Demographic (e.g. Grade 2-3 Multigrade)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public (Visible for Forking)'),
                  value: isPublic,
                  onChanged: (val) => setDialogState(() => isPublic = val),
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              final plan = await ref
                  .read(lessonPlansProvider.notifier)
                  .createLessonPlan(
                    title: titleCtrl.text,
                    subject: subjectCtrl.text,
                    primaryLanguage: langCtrl.text,
                    suggestedDemographic: demoCtrl.text,
                    isPublic: isPublic,
                  );
              if (ctx.mounted) Navigator.pop(ctx, plan);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}
