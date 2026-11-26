import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/auth_provider.dart';
import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../data/forum_models.dart';
import '../data/forum_repository.dart';
import '../providers/forum_provider.dart';
import 'forum_threads_screen.dart';

enum _ForumGroupFilter { all, owned, participated, other }

class ForumsScreen extends ConsumerStatefulWidget {
  const ForumsScreen({super.key});

  @override
  ConsumerState<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends ConsumerState<ForumsScreen> {
  final _searchCtrl = TextEditingController();
  _ForumGroupFilter _selectedGroup = _ForumGroupFilter.all;

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
        builder: (ctx, setState) {
          final screenWidth = MediaQuery.sizeOf(ctx).width;
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Text('Open Lesson Plan Forum'),
            content: SizedBox(
              width: screenWidth > 520 ? 460 : double.maxFinite,
              child: SingleChildScrollView(
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
                              SnackBar(
                                content: Text('Failed to open forum: $e'),
                              ),
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
          );
        },
      ),
    );

    if (opened != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ForumThreadsScreen(forum: opened),
        ),
      );
      if (mounted) {
        ref.read(forumsProvider.notifier).refresh();
        ref.invalidate(participatedForumIdsProvider);
      }
    }
  }

  bool _isOwnedLessonPlanForum(
    Forum forum,
    Map<String, LessonPlan> planById,
    int? userId,
    String? username,
  ) {
    if (forum.isLocalDraft) return true;
    final lpId = forum.lessonPlanId;
    if (lpId == null || lpId.isEmpty) return false;
    final plan = planById[lpId];
    if (plan == null) return false;
    return plan.isOwnedBy(userId, currentUsername: username) ||
        plan.isContributedBy(userId, currentUsername: username);
  }

  bool _hasUserParticipated(
    Forum forum,
    Set<String> participatedIds,
    ForumRepository repo,
    int? userId,
    String? username,
  ) {
    if (participatedIds.contains(forum.id)) return true;
    if (userId == null && (username == null || username.isEmpty)) return false;

    bool matchesUser(int? authorId, String authorName) {
      if (userId != null && authorId == userId) return true;
      if (username != null &&
          username.isNotEmpty &&
          authorName.toLowerCase() == username.toLowerCase()) {
        return true;
      }
      return false;
    }

    final threads = forum.threads.isNotEmpty
        ? forum.threads
        : repo.getCachedThreads(forum.id);

    for (final thread in threads) {
      if (matchesUser(thread.authorId, thread.authorName)) return true;

      final detail = thread.posts.isNotEmpty
          ? thread
          : repo.getCachedThreadDetail(thread.id);
      final posts = detail?.posts ?? const <ForumPost>[];
      for (final post in posts) {
        if (matchesUser(post.authorId, post.authorName)) return true;
      }
    }
    return false;
  }

  Widget _buildForumCard(
    BuildContext context,
    Forum forum, {
    required bool isOwner,
    required bool isParticipant,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isModerator = ref.watch(forumModeratorProvider(forum.lessonPlanId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ForumThreadsScreen(forum: forum),
              ),
            );
            if (mounted) {
              setState(() {});
              ref.read(forumsProvider.notifier).refresh();
              ref.invalidate(participatedForumIdsProvider);
            }
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
                          : (isOwner
                              ? colors.primaryContainer
                              : colors.secondaryContainer),
                      child: Icon(
                        forum.isLocked
                            ? Icons.lock_outline
                            : Icons.forum_outlined,
                        color: forum.isLocked
                            ? colors.onErrorContainer
                            : (isOwner
                                ? colors.onPrimaryContainer
                                : colors.onSecondaryContainer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            forum.displayTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
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
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Forum?'),
                              content: Text(
                                'Delete the discussion forum for "${forum.displayTitle}" and all its threads?',
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
                      avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(
                        '${forum.threadCount} ${forum.threadCount == 1 ? 'thread' : 'threads'}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (isOwner)
                      const Chip(
                        avatar: Icon(Icons.verified_user_outlined, size: 16),
                        label: Text('Your Lesson Plan'),
                        visualDensity: VisualDensity.compact,
                      )
                    else if (isParticipant)
                      const Chip(
                        avatar: Icon(Icons.forum, size: 16),
                        label: Text('Participated'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (forum.isLocked)
                      const Chip(
                        avatar: Icon(Icons.lock, size: 16),
                        label: Text('Locked'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (forum.isPendingSync || forum.isLocalDraft)
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forumsAsync = ref.watch(forumsProvider);
    final plans = ref.watch(lessonPlansProvider).value ?? const <LessonPlan>[];
    final currentUser = ref.watch(currentUserProvider);
    final repo = ref.watch(forumRepositoryProvider);
    final cachedParticipated = currentUser != null
        ? repo.getCachedParticipatedForumIds(currentUser.id)
        : const <String>{};
    final participatedIds =
        ref.watch(participatedForumIdsProvider).value ?? cachedParticipated;
    final planById = {for (final p in plans) p.id: p};
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
                      onPressed: () {
                        ref.read(forumsProvider.notifier).refresh();
                        ref.invalidate(participatedForumIdsProvider);
                      },
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

                final ownedForums = <Forum>[];
                final participatedForums = <Forum>[];
                final otherForums = <Forum>[];

                for (final forum in forums) {
                  if (_isOwnedLessonPlanForum(
                    forum,
                    planById,
                    currentUser?.id,
                    currentUser?.username,
                  )) {
                    ownedForums.add(forum);
                  } else if (_hasUserParticipated(
                    forum,
                    participatedIds,
                    repo,
                    currentUser?.id,
                    currentUser?.username,
                  )) {
                    participatedForums.add(forum);
                  } else {
                    otherForums.add(forum);
                  }
                }

                final showOwned = _selectedGroup == _ForumGroupFilter.all ||
                    _selectedGroup == _ForumGroupFilter.owned;
                final showParticipated =
                    _selectedGroup == _ForumGroupFilter.all ||
                        _selectedGroup == _ForumGroupFilter.participated;
                final showOther = _selectedGroup == _ForumGroupFilter.all ||
                    _selectedGroup == _ForumGroupFilter.other;

                final hasVisibleItems = (showOwned && ownedForums.isNotEmpty) ||
                    (showParticipated && participatedForums.isNotEmpty) ||
                    (showOther && otherForums.isNotEmpty);

                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text('All (${forums.length})'),
                            selected: _selectedGroup == _ForumGroupFilter.all,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _ForumGroupFilter.all,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(
                              Icons.menu_book_outlined,
                              size: 16,
                            ),
                            label: Text('My Plans (${ownedForums.length})'),
                            selected:
                                _selectedGroup == _ForumGroupFilter.owned,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _ForumGroupFilter.owned,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(Icons.forum_outlined, size: 16),
                            label: Text(
                              'Participated (${participatedForums.length})',
                            ),
                            selected: _selectedGroup ==
                                _ForumGroupFilter.participated,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  _ForumGroupFilter.participated,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(Icons.public_outlined, size: 16),
                            label: Text(
                              'Other Forums (${otherForums.length})',
                            ),
                            selected:
                                _selectedGroup == _ForumGroupFilter.other,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _ForumGroupFilter.other,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(forumsProvider.notifier).refresh();
                          ref.invalidate(participatedForumIdsProvider);
                        },
                        child: !hasVisibleItems
                            ? ListView(
                                padding: const EdgeInsets.all(32),
                                children: const [
                                  Center(
                                    child: Text('No forums in this category.'),
                                  ),
                                ],
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                children: [
                                  if (showOwned && ownedForums.isNotEmpty) ...[
                                    _ForumGroupHeader(
                                      icon: Icons.menu_book_outlined,
                                      title: 'My Lesson Plan Forums',
                                      subtitle:
                                          'Lesson plans created or co-authored by you',
                                      count: ownedForums.length,
                                    ),
                                    ...ownedForums.map(
                                      (f) => _buildForumCard(
                                        context,
                                        f,
                                        isOwner: true,
                                        isParticipant: false,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (showParticipated &&
                                      participatedForums.isNotEmpty) ...[
                                    _ForumGroupHeader(
                                      icon: Icons.forum_outlined,
                                      title: 'Participated Forums',
                                      subtitle:
                                          'Discussions you started or replied to',
                                      count: participatedForums.length,
                                    ),
                                    ...participatedForums.map(
                                      (f) => _buildForumCard(
                                        context,
                                        f,
                                        isOwner: false,
                                        isParticipant: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (showOther && otherForums.isNotEmpty) ...[
                                    _ForumGroupHeader(
                                      icon: Icons.public_outlined,
                                      title: 'Other Forums',
                                      subtitle:
                                          'Community lesson plan discussions',
                                      count: otherForums.length,
                                    ),
                                    ...otherForums.map(
                                      (f) => _buildForumCard(
                                        context,
                                        f,
                                        isOwner: false,
                                        isParticipant: false,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
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

class _ForumGroupHeader extends StatelessWidget {
  const _ForumGroupHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Badge(
            label: Text('$count'),
            backgroundColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ],
      ),
    );
  }
}
