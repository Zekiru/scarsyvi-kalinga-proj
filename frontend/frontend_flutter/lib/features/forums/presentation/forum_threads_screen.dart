import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/forum_models.dart';
import '../data/forum_repository.dart';
import '../providers/forum_provider.dart';
import 'thread_detail_screen.dart';

class ForumThreadsScreen extends ConsumerStatefulWidget {
  const ForumThreadsScreen({super.key, required this.forum});

  final Forum forum;

  @override
  ConsumerState<ForumThreadsScreen> createState() => _ForumThreadsScreenState();
}

class _ForumThreadsScreenState extends ConsumerState<ForumThreadsScreen> {
  late Forum _forum;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _forum = widget.forum;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateThreadDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<ForumThread>(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('New Discussion Thread'),
          content: SizedBox(
            width: screenWidth > 520 ? 460 : double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Thread Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Opening Message / Adaptation Proposal',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
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
                final user = ref.read(currentUserProvider);
                final thread =
                    await ref.read(forumRepositoryProvider).createThread(
                          forumId: _forum.id,
                          title: titleCtrl.text,
                          body: bodyCtrl.text,
                          authorId: user?.id,
                          authorName: user?.username ?? '',
                        );
                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(forumThreadsProvider(_forum.id));
                ref.read(forumsProvider.notifier).refresh();
                if (ctx.mounted) Navigator.pop(ctx, thread);
              },
              child: const Text('Post Thread'),
            ),
          ],
        );
      },
    );

    if (created != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadDetailScreen(
            threadId: created.id,
            lessonPlanId: _forum.lessonPlanId,
            isForumLocked: _forum.isLocked,
          ),
        ),
      );
      if (mounted) {
        ref.invalidate(forumThreadsProvider(_forum.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(forumThreadsProvider(_forum.id));
    final currentUser = ref.watch(currentUserProvider);
    final canModerate = ref.watch(forumModeratorProvider(_forum.lessonPlanId));
    final canCreateThread = !_forum.isLocked || canModerate;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _forum.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Lesson Plan Discussion Workspace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (canModerate && !_forum.isLocalDraft)
            IconButton(
              tooltip: _forum.isLocked ? 'Unlock Forum' : 'Lock Forum',
              icon: Icon(
                _forum.isLocked ? Icons.lock_open : Icons.lock_outline,
              ),
              onPressed: () async {
                final updated = await ref
                    .read(forumRepositoryProvider)
                    .toggleForumLock(_forum.serverId!);
                setState(() => _forum = updated);
                ref.read(forumsProvider.notifier).refresh();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_forum.isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colors.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canModerate
                          ? 'This forum is locked. Only moderators can post new threads or replies.'
                          : 'This forum is locked. New threads and replies are disabled.',
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Filter threads by title, body, or author...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) =>
                  setState(() => _search = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Failed to load threads: $err')),
              data: (threads) {
                final visible = threads.where((t) {
                  final canSee = !t.isHidden ||
                      canModerate ||
                      (currentUser != null && t.authorId == currentUser.id);
                  if (!canSee) return false;
                  if (_search.isEmpty) return true;
                  return t.title.toLowerCase().contains(_search) ||
                      t.body.toLowerCase().contains(_search) ||
                      t.authorName.toLowerCase().contains(_search);
                }).toList()
                  ..sort((a, b) {
                    if (a.isPinned != b.isPinned) {
                      return a.isPinned ? -1 : 1;
                    }
                    return b.id.compareTo(a.id);
                  });

                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isNotEmpty
                          ? 'No threads match "$_search".'
                          : 'No threads yet. Tap + to start a topic.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(forumThreadsProvider(_forum.id)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final thread = visible[index];
                      final hasBadges = thread.isPendingSync ||
                          thread.isLocalDraft ||
                          thread.isHidden ||
                          thread.isLocked;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ThreadDetailScreen(
                                  threadId: thread.id,
                                  lessonPlanId: _forum.lessonPlanId,
                                  isForumLocked: _forum.isLocked,
                                ),
                              ),
                            );
                            if (mounted) {
                              ref.invalidate(forumThreadsProvider(_forum.id));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: thread.isPinned
                                          ? colors.primaryContainer
                                          : colors.surfaceContainerHighest,
                                      child: Icon(
                                        thread.isPinned
                                            ? Icons.push_pin
                                            : (thread.isLocked
                                                ? Icons.lock_outline
                                                : Icons.chat_bubble_outline),
                                        color: thread.isPinned
                                            ? colors.onPrimaryContainer
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            thread.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (thread.body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              thread.body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (thread.authorName.isNotEmpty)
                                                'by @${thread.authorName}',
                                              '${thread.postCount} ${thread.postCount == 1 ? 'reply' : 'replies'}',
                                            ].join(' • '),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                if (hasBadges) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (thread.isPendingSync ||
                                          thread.isLocalDraft)
                                        const Chip(
                                          label: Text('Queued'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (thread.isHidden)
                                        const Chip(
                                          label: Text('Hidden'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (thread.isLocked)
                                        const Chip(
                                          label: Text('Locked'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
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
      floatingActionButton: canCreateThread
          ? FloatingActionButton.extended(
              onPressed: _showCreateThreadDialog,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New Thread'),
            )
          : null,
    );
  }
}
