import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../../forums/presentation/forum_threads_screen.dart';
import '../../forums/providers/forum_provider.dart';
import '../data/curriculum_models.dart';
import '../data/curriculum_repository.dart';
import '../providers/curriculum_provider.dart';
import 'widgets/grade_levels_tab.dart';
import 'widgets/lesson_flows_tab.dart';
import 'widgets/lesson_gradings_tab.dart';
import 'widgets/lesson_plan_form_dialog.dart';
import 'widgets/materials_tab.dart';
import 'widgets/overview_tab.dart';

class LessonPlanDetailScreen extends ConsumerWidget {
  const LessonPlanDetailScreen({
    super.key,
    required this.lessonPlanId,
  });

  final String lessonPlanId;

  Future<void> _openForum(
    BuildContext context,
    WidgetRef ref,
    LessonPlan plan,
  ) async {
    try {
      final forum = await ref
          .read(forumsProvider.notifier)
          .openOrCreateForumForLessonPlan(
            lessonPlanId: plan.id,
            lessonPlanTitle: plan.title,
          );
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ForumThreadsScreen(forum: forum),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open forum: $e')),
        );
      }
    }
  }

  Future<void> _forkPlan(
    BuildContext context,
    WidgetRef ref,
    LessonPlan plan,
  ) async {
    final forked = await ref
        .read(lessonPlansProvider.notifier)
        .forkLessonPlan(plan.serverId!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forked "${forked.title}"')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LessonPlanDetailScreen(
            lessonPlanId: forked.id,
          ),
        ),
      );
    }
  }

  Future<void> _toggleApproval(
    WidgetRef ref,
    LessonPlan plan,
  ) async {
    await ref.read(curriculumRepositoryProvider).setLessonPlanApproval(
          lessonPlanId: plan.id,
          isApproved: !plan.isApproved,
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(lessonPlanId));
    ref.read(lessonPlansProvider.notifier).refresh();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson Plan?'),
        content: Text(
          'Are you sure you want to delete "${plan.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(lessonPlansProvider.notifier).deleteLessonPlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${plan.title}"')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(lessonPlanDetailProvider(lessonPlanId));
    final currentUser = ref.watch(currentUserProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 480;

    return planAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Lesson Plan')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Lesson Plan')),
        body: Center(child: Text('Error loading lesson plan: $err')),
      ),
      data: (plan) {
        final userId = currentUser?.id;
        final username = currentUser?.username;
        final isOwner = plan.isCreatedBy(userId, currentUsername: username);
        final isAdmin = currentUser?.canAdminister ?? false;
        final canDelete = isOwner || isAdmin;
        final canEdit = plan.isOwnedBy(userId, currentUsername: username) ||
            plan.isContributedBy(userId, currentUsername: username) ||
            isAdmin;
        final canReview = currentUser?.canModerate ?? false;
        final canFork = !plan.isLocalDraft && plan.serverId != null;
        final primaryAuthorLabel = plan.primaryAuthorDisplay(
          currentUserId: userId,
          currentUsername: username,
        );

        final hasOverflowItems = canFork || canReview || canDelete;

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 4,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (primaryAuthorLabel.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Made by $primaryAuthorLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Discuss in Forum',
                  icon: const Icon(Icons.forum_outlined),
                  onPressed: () => _openForum(context, ref, plan),
                ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit Lesson Plan',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showLessonPlanFormDialog(
                      context,
                      ref,
                      existingPlan: plan,
                    ),
                  ),
                if (!isCompact) ...[
                  if (canFork)
                    IconButton(
                      tooltip: 'Fork Lesson Plan',
                      icon: const Icon(Icons.fork_right),
                      onPressed: () => _forkPlan(context, ref, plan),
                    ),
                  if (canReview)
                    IconButton(
                      tooltip: plan.isApproved
                          ? 'Revoke Approval'
                          : 'Approve Lesson Plan',
                      icon: Icon(
                        plan.isApproved
                            ? Icons.verified
                            : Icons.verified_outlined,
                      ),
                      onPressed: () => _toggleApproval(ref, plan),
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Delete Lesson Plan',
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _confirmDelete(context, ref, plan),
                    ),
                ] else if (hasOverflowItems)
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    onSelected: (value) async {
                      switch (value) {
                        case 'fork':
                          await _forkPlan(context, ref, plan);
                        case 'approve':
                          await _toggleApproval(ref, plan);
                        case 'delete':
                          await _confirmDelete(context, ref, plan);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (canFork)
                        const PopupMenuItem(
                          value: 'fork',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.fork_right),
                            title: Text('Fork Lesson Plan'),
                          ),
                        ),
                      if (canReview)
                        PopupMenuItem(
                          value: 'approve',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              plan.isApproved
                                  ? Icons.verified
                                  : Icons.verified_outlined,
                            ),
                            title: Text(
                              plan.isApproved
                                  ? 'Revoke Approval'
                                  : 'Approve Lesson Plan',
                            ),
                          ),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline,
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                            title: Text(
                              'Delete Lesson Plan',
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Grades & Standards'),
                  Tab(text: 'Flow of Lesson'),
                  Tab(text: 'Grading Tasks'),
                  Tab(text: 'Materials'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                OverviewTab(plan: plan),
                GradeLevelsTab(
                  plan: plan,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
                LessonFlowsTab(
                  plan: plan,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
                LessonGradingsTab(
                  plan: plan,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
                MaterialsTab(
                  plan: plan,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
