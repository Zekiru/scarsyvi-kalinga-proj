import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum_models.dart';
import '../providers/curriculum_provider.dart';
import 'lesson_plan_detail_screen.dart';

class LessonPlansScreen extends ConsumerStatefulWidget {
  const LessonPlansScreen({super.key});

  @override
  ConsumerState<LessonPlansScreen> createState() => _LessonPlansScreenState();
}

class _LessonPlansScreenState extends ConsumerState<LessonPlansScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPublic = true;

    final created = await showDialog<LessonPlan>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Lesson Plan'),
          content: SizedBox(
            width: 420,
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
                      labelText: 'Subject (e.g. Science, Mathematics)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Overview / Learning Goals',
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
                      description: descCtrl.text,
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

    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonPlanDetailScreen(lessonPlanId: created.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(lessonPlansProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search lesson plans by title or subject...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(lessonPlansProvider.notifier)
                              .refresh(search: '');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                ref.read(lessonPlansProvider.notifier).refresh(search: val);
              },
            ),
          ),
          Expanded(
            child: plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load lesson plans: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(lessonPlansProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return const Center(
                    child: Text('No lesson plans yet. Tap + to create one.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(lessonPlansProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: plans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            plan.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${plan.subject}${plan.authorName.isNotEmpty ? ' • by @${plan.authorName}' : ''}',
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (plan.isPendingSync || plan.isLocalDraft)
                                const Chip(
                                  label: Text('Queued'),
                                  avatar: Icon(Icons.schedule, size: 16),
                                )
                              else if (plan.isApproved)
                                const Chip(
                                  label: Text('Approved'),
                                  avatar: Icon(Icons.verified_outlined, size: 16),
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LessonPlanDetailScreen(
                                  lessonPlanId: plan.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}
