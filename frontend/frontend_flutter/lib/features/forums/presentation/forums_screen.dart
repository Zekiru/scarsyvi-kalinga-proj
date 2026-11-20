import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../data/forum_models.dart';
import '../providers/forum_provider.dart';
import 'forum_threads_screen.dart';

class ForumsScreen extends ConsumerStatefulWidget {
  const ForumsScreen({super.key});

  @override
  ConsumerState<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends ConsumerState<ForumsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateForumDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    List<LessonPlan> plans = const [];
    try {
      plans = await ref.read(lessonPlansProvider.future);
    } catch (_) {}

    if (!mounted) return;
    LessonPlan? selectedPlan;

    final created = await showDialog<Forum>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Discussion Forum'),
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
                      labelText: 'Forum Title',
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
                      labelText: 'Description / Topic Scope',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (plans.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LessonPlan?>(
                      initialValue: selectedPlan,
                      decoration: const InputDecoration(
                        labelText: 'Linked Lesson Plan (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<LessonPlan?>(
                          value: null,
                          child: Text('General Community Forum'),
                        ),
                        ...plans.map(
                          (lp) => DropdownMenuItem<LessonPlan?>(
                            value: lp,
                            child: Text(
                              lp.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => selectedPlan = val),
                    ),
                  ],
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
                final forum =
                    await ref.read(forumsProvider.notifier).createForum(
                          title: titleCtrl.text,
                          description: descCtrl.text,
                          lessonPlanId: selectedPlan?.id,
                          lessonPlanTitle: selectedPlan?.title ?? '',
                        );
                if (ctx.mounted) Navigator.pop(ctx, forum);
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
          builder: (_) => ForumThreadsScreen(forum: created),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final forumsAsync = ref.watch(forumsProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search forums...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(forumsProvider.notifier).refresh(search: '');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                ref.read(forumsProvider.notifier).refresh(search: val);
              },
            ),
          ),
          Expanded(
            child: forumsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load forums: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(forumsProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (forums) {
                if (forums.isEmpty) {
                  return const Center(
                    child: Text('No forums yet. Tap + to start a discussion.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(forumsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: forums.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final forum = forums[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              forum.isLocked
                                  ? Icons.lock_outline
                                  : Icons.forum_outlined,
                            ),
                          ),
                          title: Text(
                            forum.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (forum.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    forum.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (forum.lessonPlanTitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Lesson Plan: ${forum.lessonPlanTitle}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (forum.isPendingSync || forum.isLocalDraft)
                                const Chip(label: Text('Queued'))
                              else if (forum.isLocked)
                                const Chip(label: Text('Locked')),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForumThreadsScreen(forum: forum),
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
        onPressed: _showCreateForumDialog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Forum'),
      ),
    );
  }
}
