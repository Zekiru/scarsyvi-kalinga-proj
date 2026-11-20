import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/auth_provider.dart';
import '../data/forum_repository.dart';
import '../providers/forum_provider.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({
    super.key,
    required this.threadId,
    this.isForumLocked = false,
  });

  final String threadId;
  final bool isForumLocked;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _replyCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(forumReplyHelperProvider)(
        threadId: widget.threadId,
        content: text,
      );
      _replyCtrl.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(threadDetailProvider(widget.threadId));
    final currentUser = ref.watch(currentUserProvider);
    final canModerate = currentUser?.canModerate ?? false;

    return threadAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Thread')),
        body: Center(child: Text('Failed to load thread: $err')),
      ),
      data: (thread) {
        final isLocked = widget.isForumLocked || thread.isLocked;
        final visiblePosts =
            thread.posts.where((p) => !p.isHidden || canModerate).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(thread.title),
            actions: [
              if (canModerate && !thread.isLocalDraft)
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    final repo = ref.read(forumRepositoryProvider);
                    final sId = thread.serverId!;
                    if (action == 'pin') {
                      await repo.moderateThread(
                        threadServerId: sId,
                        isPinned: !thread.isPinned,
                      );
                    } else if (action == 'lock') {
                      await repo.moderateThread(
                        threadServerId: sId,
                        isLocked: !thread.isLocked,
                      );
                    } else if (action == 'hide') {
                      await repo.moderateThread(
                        threadServerId: sId,
                        isHidden: !thread.isHidden,
                      );
                    }
                    ref.invalidate(threadDetailProvider(widget.threadId));
                    ref.invalidate(forumThreadsProvider(thread.forumId));
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(thread.isPinned ? 'Unpin Thread' : 'Pin Thread'),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      child:
                          Text(thread.isLocked ? 'Unlock Thread' : 'Lock Thread'),
                    ),
                    PopupMenuItem(
                      value: 'hide',
                      child:
                          Text(thread.isHidden ? 'Unhide Thread' : 'Hide Thread'),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  thread.authorName.isNotEmpty
                                      ? '@${thread.authorName}'
                                      : 'Author',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (thread.isPendingSync || thread.isLocalDraft)
                                  const Chip(label: Text('Queued')),
                                if (thread.isLocked)
                                  const Chip(label: Text('Locked')),
                              ],
                            ),
                            if (thread.body.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(thread.body),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Replies (${visiblePosts.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (visiblePosts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No replies yet. Join the conversation!'),
                        ),
                      )
                    else
                      ...visiblePosts.map(
                        (post) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Text(
                                  post.authorName.isNotEmpty
                                      ? '@${post.authorName}'
                                      : 'Member',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (post.authorRole.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${post.authorRole})',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                const Spacer(),
                                if (post.isPendingSync || post.isLocalDraft)
                                  const Chip(label: Text('Queued')),
                                if (post.isHidden)
                                  const Chip(label: Text('Hidden')),
                                if (canModerate && !post.isLocalDraft)
                                  IconButton(
                                    tooltip: post.isHidden
                                        ? 'Unhide Reply'
                                        : 'Hide Reply',
                                    icon: Icon(
                                      post.isHidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(forumRepositoryProvider)
                                          .toggleHidePost(
                                            threadId: thread.id,
                                            postServerId: post.serverId!,
                                          );
                                      ref.invalidate(
                                        threadDetailProvider(widget.threadId),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(post.content),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isLocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Text(
                    'Replies are disabled because this discussion is locked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                )
              else
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Write a reply...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendReply,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
