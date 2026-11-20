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

  @override
  void initState() {
    super.initState();
    _forum = widget.forum;
  }

  Future<void> _showCreateThreadDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<ForumThread>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Thread'),
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
                    labelText: 'Opening Message',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              if (ctx.mounted) Navigator.pop(ctx, thread);
            },
            child: const Text('Post Thread'),
          ),
        ],
      ),
    );

    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadDetailScreen(
            threadId: created.id,
            isForumLocked: _forum.isLocked,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(forumThreadsProvider(_forum.id));
    final currentUser = ref.watch(currentUserProvider);
    final canModerate = currentUser?.canModerate ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_forum.title),
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
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This forum is locked. New threads and replies are disabled.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Failed to load threads: $err')),
              data: (threads) {
                final visible = threads
                    .where((t) => !t.isHidden || canModerate)
                    .toList()
                  ..sort((a, b) {
                    if (a.isPinned != b.isPinned) {
                      return a.isPinned ? -1 : 1;
                    }
                    return b.id.compareTo(a.id);
                  });

                if (visible.isEmpty) {
                  return const Center(
                    child: Text('No threads yet. Tap + to start a topic.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(forumThreadsProvider(_forum.id)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final thread = visible[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            thread.isPinned
                                ? Icons.push_pin
                                : (thread.isLocked
                                    ? Icons.lock_outline
                                    : Icons.chat_bubble_outline),
                          ),
                          title: Text(
                            thread.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (thread.authorName.isNotEmpty)
                                'by @${thread.authorName}',
                              '${thread.postCount} replies',
                            ].join(' • '),
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (thread.isPendingSync || thread.isLocalDraft)
                                const Chip(label: Text('Queued')),
                              if (thread.isHidden)
                                const Chip(label: Text('Hidden')),
                              if (thread.isLocked)
                                const Chip(label: Text('Locked')),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ThreadDetailScreen(
                                  threadId: thread.id,
                                  isForumLocked: _forum.isLocked,
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
      floatingActionButton: _forum.isLocked
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateThreadDialog,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New Thread'),
            ),
    );
  }
}
