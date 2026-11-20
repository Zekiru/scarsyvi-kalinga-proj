import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
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
        final isOwner = plan.isCreatedBy(currentUser?.id);
        final isAdmin = currentUser?.canAdminister ?? false;
        final canDelete = isOwner || isAdmin;
        final canEdit = plan.isOwnedBy(currentUser?.id) ||
            plan.isContributedBy(currentUser?.id) ||
            isAdmin;
        final canReview = currentUser?.canModerate ?? false;

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(plan.title),
              actions: [
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
                if (!plan.isLocalDraft)
                  IconButton(
                    tooltip: 'Fork Lesson Plan',
                    icon: const Icon(Icons.fork_right),
                    onPressed: () async {
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
                    },
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
                    onPressed: () async {
                      await ref
                          .read(curriculumRepositoryProvider)
                          .setLessonPlanApproval(
                            lessonPlanId: plan.id,
                            isApproved: !plan.isApproved,
                          );
                      ref.read(syncStatusProvider.notifier).refreshCounts();
                      ref.invalidate(lessonPlanDetailProvider(lessonPlanId));
                      ref.read(lessonPlansProvider.notifier).refresh();
                    },
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
              ],
              bottom: const TabBar(
                isScrollable: true,
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
                GradeLevelsTab(plan: plan, canEdit: canEdit),
                LessonFlowsTab(plan: plan, canEdit: canEdit),
                LessonGradingsTab(plan: plan, canEdit: canEdit),
                MaterialsTab(plan: plan, canEdit: canEdit),
              ],
            ),
          ),
        );
      },
    );
  }
}
