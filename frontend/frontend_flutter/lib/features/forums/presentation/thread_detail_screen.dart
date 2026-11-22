import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/forum_models.dart';
import '../data/forum_repository.dart';
import '../providers/forum_provider.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({
    super.key,
    required this.threadId,
    this.lessonPlanId,
    this.isForumLocked = false,
  });

  final String threadId;
  final String? lessonPlanId;
  final bool isForumLocked;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _replyFocusNode = FocusNode();
  ForumPost? _replyingTo;
  bool _isSending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    _replyFocusNode.dispose();
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
        parentPostId: _replyingTo?.id,
        parentAuthorUsername: _replyingTo?.authorName ?? '',
      );
      _replyCtrl.clear();
      setState(() => _replyingTo = null);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showEditThreadDialog(ForumThread thread) async {
    final titleCtrl = TextEditingController(text: thread.title);
    final bodyCtrl = TextEditingController(text: thread.body);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Thread'),
        content: SizedBox(
          width: 460,
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
                    labelText: 'Body',
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
              await ref.read(forumRepositoryProvider).updateThread(
                    thread: thread,
                    title: titleCtrl.text,
                    body: bodyCtrl.text,
                  );
              ref.read(syncStatusProvider.notifier).refreshCounts();
              ref.invalidate(threadDetailProvider(widget.threadId));
              ref.invalidate(forumThreadsProvider(thread.forumId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteThread(ForumThread thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Thread?'),
        content: Text(
          'Delete "${thread.title}" and all its replies? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(forumRepositoryProvider).deleteThread(thread);
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(forumThreadsProvider(thread.forumId));
      ref.read(forumsProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showEditPostDialog(ForumThread thread, ForumPost post) async {
    final contentCtrl = TextEditingController(text: post.content);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Reply'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reply Content',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              await ref.read(forumRepositoryProvider).updatePost(
                    threadId: thread.id,
                    post: post,
                    content: contentCtrl.text,
                  );
              ref.read(syncStatusProvider.notifier).refreshCounts();
              ref.invalidate(threadDetailProvider(widget.threadId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost(ForumThread thread, ForumPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reply?'),
        content: const Text('Delete this reply? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(forumRepositoryProvider).deletePost(
            threadId: thread.id,
            post: post,
          );
      ref.read(syncStatusProvider.notifier).refreshCounts();
      ref.invalidate(threadDetailProvider(widget.threadId));
      ref.invalidate(forumThreadsProvider(thread.forumId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(threadDetailProvider(widget.threadId));
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
        final effectiveLpId = widget.lessonPlanId ?? thread.lessonPlanId;
        final canModerate = ref.watch(forumModeratorProvider(effectiveLpId));
        final isThreadAuthor =
            currentUser != null && thread.authorId == currentUser.id;
        final canEditOrDeleteThread = isThreadAuthor || canModerate;
        final isLockedForUser =
            (widget.isForumLocked || thread.isLocked) && !canModerate;

        final visiblePosts = thread.posts
            .where(
              (p) =>
                  !p.isHidden ||
                  canModerate ||
                  (currentUser != null && p.authorId == currentUser.id),
            )
            .toList();
        final postById = {for (final p in thread.posts) p.id: p};

        return Scaffold(
          appBar: AppBar(
            title: Text(thread.title),
            actions: [
              if (canEditOrDeleteThread)
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    final repo = ref.read(forumRepositoryProvider);
                    if (action == 'edit') {
                      await _showEditThreadDialog(thread);
                    } else if (action == 'delete') {
                      await _confirmDeleteThread(thread);
                    } else if (canModerate && !thread.isLocalDraft) {
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
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Thread'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Thread'),
                    ),
                    if (canModerate && !thread.isLocalDraft) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(
                          thread.isPinned ? 'Unpin Thread' : 'Pin Thread',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'lock',
                        child: Text(
                          thread.isLocked ? 'Unlock Thread' : 'Lock Thread',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'hide',
                        child: Text(
                          thread.isHidden ? 'Unhide Thread' : 'Hide Thread',
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(threadDetailProvider(widget.threadId)),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: colors.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    child: Text(
                                      thread.authorName.isNotEmpty
                                          ? thread.authorName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    thread.authorName.isNotEmpty
                                        ? '@${thread.authorName}'
                                        : 'Author',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (thread.isPinned)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Chip(
                                        label: Text('Pinned'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  if (thread.isHidden)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Chip(
                                        label: Text('Hidden'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  if (thread.isPendingSync ||
                                      thread.isLocalDraft)
                                    const Chip(
                                      label: Text('Queued'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (thread.isLocked)
                                    const Chip(
                                      label: Text('Locked'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              if (thread.body.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  thread.body,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Replies (${visiblePosts.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visiblePosts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child:
                                Text('No replies yet. Join the conversation!'),
                          ),
                        )
                      else
                        ...visiblePosts.map((post) {
                          final isNested = post.parentPostId != null &&
                              post.parentPostId!.isNotEmpty;
                          final parentPost =
                              isNested ? postById[post.parentPostId!] : null;
                          final repliedToUser = post.parentAuthorUsername
                                  .isNotEmpty
                              ? post.parentAuthorUsername
                              : (parentPost?.authorName ?? '');
                          final isPostAuthor = currentUser != null &&
                              post.authorId == currentUser.id;
                          final canManagePost = isPostAuthor || canModerate;

                          return Padding(
                            padding: EdgeInsets.only(
                              left: isNested ? 24 : 0,
                              bottom: 8,
                            ),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  8,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        const Spacer(),
                                        if (post.isPendingSync ||
                                            post.isLocalDraft)
                                          const Chip(
                                            label: Text('Queued'),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        if (post.isHidden)
                                          const Chip(
                                            label: Text('Hidden'),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        if (!isLockedForUser)
                                          IconButton(
                                            tooltip: 'Reply to comment',
                                            icon: const Icon(
                                              Icons.reply,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(
                                                () => _replyingTo = post,
                                              );
                                              _replyFocusNode.requestFocus();
                                            },
                                          ),
                                        if (canManagePost)
                                          PopupMenuButton<String>(
                                            iconSize: 18,
                                            onSelected: (action) async {
                                              if (action == 'edit') {
                                                await _showEditPostDialog(
                                                  thread,
                                                  post,
                                                );
                                              } else if (action == 'delete') {
                                                await _confirmDeletePost(
                                                  thread,
                                                  post,
                                                );
                                              } else if (action == 'hide' &&
                                                  canModerate &&
                                                  !post.isLocalDraft) {
                                                await ref
                                                    .read(
                                                      forumRepositoryProvider,
                                                    )
                                                    .toggleHidePost(
                                                      threadId: thread.id,
                                                      postServerId:
                                                          post.serverId!,
                                                    );
                                                ref.invalidate(
                                                  threadDetailProvider(
                                                    widget.threadId,
                                                  ),
                                                );
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit Reply'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete Reply'),
                                              ),
                                              if (canModerate &&
                                                  !post.isLocalDraft) ...[
                                                const PopupMenuDivider(),
                                                PopupMenuItem(
                                                  value: 'hide',
                                                  child: Text(
                                                    post.isHidden
                                                        ? 'Unhide Reply'
                                                        : 'Hide Reply',
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (isNested) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border(
                                            left: BorderSide(
                                              color: colors.primary,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          repliedToUser.isNotEmpty
                                              ? 'Replying to @$repliedToUser${parentPost != null ? ': "${parentPost.content}"' : ''}'
                                              : 'Replying to comment #${post.parentPostId}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(post.content),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              if (isLockedForUser)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: colors.errorContainer,
                  child: Text(
                    'Replies are disabled because this discussion is locked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                )
              else
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          color: colors.secondaryContainer,
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: colors.onSecondaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Replying to @${_replyingTo!.authorName.isNotEmpty ? _replyingTo!.authorName : 'Member'}: "${_replyingTo!.content}"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    setState(() => _replyingTo = null),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyCtrl,
                                focusNode: _replyFocusNode,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: _replyingTo != null
                                      ? 'Write a nested reply...'
                                      : 'Write a reply...',
                                  border: const OutlineInputBorder(),
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
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
