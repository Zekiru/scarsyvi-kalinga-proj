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

  Future<void> _showOpenLessonPlanForumDialog() async {
    final formKey = GlobalKey<FormState>();

    List<LessonPlan> plans = const [];
    try {
      plans = await ref.read(lessonPlansProvider.future);
    } catch (_) {}

    if (!mounted) return;

    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create or sync a Lesson Plan first before opening a discussion forum.',
          ),
        ),
      );
      return;
    }

    LessonPlan selectedPlan = plans.first;
    bool isSubmitting = false;

    final opened = await showDialog<Forum>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Open Lesson Plan Forum'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a Lesson Plan to open or initialize its dedicated discussion workspace.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<LessonPlan>(
                    initialValue: selectedPlan,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Plan',
                      border: OutlineInputBorder(),
                    ),
                    items: plans
                        .map(
                          (lp) => DropdownMenuItem<LessonPlan>(
                            value: lp,
                            child: Text(
                              lp.subject.isNotEmpty
                                  ? '${lp.title} (${lp.subject})'
                                  : lp.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedPlan = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        final forum = await ref
                            .read(forumsProvider.notifier)
                            .openOrCreateForumForLessonPlan(
                              lessonPlanId: selectedPlan.id,
                              lessonPlanTitle: selectedPlan.title,
                            );
                        if (ctx.mounted) Navigator.pop(ctx, forum);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to open forum: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setState(() => isSubmitting = false);
                      }
                    },
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text(isSubmitting ? 'Opening...' : 'Open Forum'),
            ),
          ],
        ),
      ),
    );

    if (opened != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ForumThreadsScreen(forum: opened),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final forumsAsync = ref.watch(forumsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search lesson plan forums...',
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No lesson plan forums active yet.\nTap "Open Forum" to start a discussion for a lesson plan.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(forumsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: forums.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final forum = forums[index];
                      final isModerator =
                          ref.watch(forumModeratorProvider(forum.lessonPlanId));

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForumThreadsScreen(forum: forum),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: forum.isLocked
                                          ? colors.errorContainer
                                          : colors.primaryContainer,
                                      child: Icon(
                                        forum.isLocked
                                            ? Icons.lock_outline
                                            : Icons.forum_outlined,
                                        color: forum.isLocked
                                            ? colors.onErrorContainer
                                            : colors.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            forum.displayTitle,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (forum.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              forum.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isModerator)
                                      IconButton(
                                        tooltip: 'Delete Forum',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Forum?'),
                                              content: Text(
                                                'Delete the discussion forum for "${forum.displayTitle}" and all its threads?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await ref
                                                .read(forumsProvider.notifier)
                                                .deleteForum(forum.id);
                                          }
                                        },
                                      ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Chip(
                                      avatar: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '${forum.threadCount} ${forum.threadCount == 1 ? 'thread' : 'threads'}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (forum.isLocked)
                                      const Chip(
                                        avatar: Icon(Icons.lock, size: 16),
                                        label: Text('Locked'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (forum.isPendingSync ||
                                        forum.isLocalDraft)
                                      const Chip(
                                        avatar: Icon(Icons.sync, size: 16),
                                        label: Text('Pending Sync'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
        onPressed: _showOpenLessonPlanForumDialog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Open Forum'),
      ),
    );
  }
}
