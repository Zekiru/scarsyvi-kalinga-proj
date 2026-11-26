import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_model.dart';
import '../../accounts/providers/auth_provider.dart';
import '../../classrooms/data/classroom_models.dart';
import '../../classrooms/presentation/classroom_detail_screen.dart';
import '../../classrooms/presentation/classrooms_screen.dart';
import '../../classrooms/providers/classroom_provider.dart';
import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/presentation/lesson_plan_detail_screen.dart';
import '../../curriculum/presentation/widgets/lesson_plan_form_dialog.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../../forums/data/forum_models.dart';
import '../../forums/presentation/forum_threads_screen.dart';
import '../../forums/providers/forum_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  /// Optional callback if AppShell exposes tab switching (e.g. 1=Classes, 2=Plans, 3=Forums)
  final ValueChanged<int>? onNavigateToTab;

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayFirstName(Account? account) {
    if (account == null) return 'Educator';
    if (account.firstName.trim().isNotEmpty) return account.firstName.trim();
    if (account.username.trim().isNotEmpty) return account.username.trim();
    return 'Educator';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserProvider);
    final classroomsAsync = ref.watch(classroomsProvider);
    final plansAsync = ref.watch(lessonPlansProvider);
    final forumsAsync = ref.watch(forumsProvider);
    final participatedIds =
        ref.watch(participatedForumIdsProvider).value ?? const <String>{};

    final userId = account?.id;
    final username = account?.username;

    // 1. Owned Classrooms
    final allClassrooms = classroomsAsync.value ?? const <Classroom>[];
    final myClassrooms = allClassrooms
        .where(
          (c) =>
              c.isLocalDraft ||
              (userId != null && c.adviserId != null && c.adviserId == userId),
        )
        .toList();

    // 2. Owned / Co-owned Lesson Plans & Suggested Plans by Learning Area
    final allPlans = plansAsync.value ?? const <LessonPlan>[];
    final myPlans = <LessonPlan>[];
    final otherPlans = <LessonPlan>[];

    for (final plan in allPlans) {
      if (plan.isOwnedBy(userId, currentUsername: username) ||
          plan.isContributedBy(userId, currentUsername: username)) {
        myPlans.add(plan);
      } else {
        otherPlans.add(plan);
      }
    }

    final mySubjects = myPlans
        .map((p) => p.subject.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final suggestedPlans = mySubjects.isEmpty
        ? const <LessonPlan>[]
        : otherPlans
            .where((p) => mySubjects.contains(p.subject.trim().toLowerCase()))
            .take(3)
            .toList();

    // 3. Forums needing attention (owned LP forums or participated forums with active threads)
    final allForums = forumsAsync.value ?? const <Forum>[];
    final myPlanIds = myPlans.map((p) => p.id).toSet();
    final relevantForums = allForums
        .where(
          (f) =>
              f.threadCount > 0 &&
              ((f.lessonPlanId != null && myPlanIds.contains(f.lessonPlanId)) ||
                  participatedIds.contains(f.id)),
        )
        .take(3)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(classroomsProvider.notifier).refresh(),
            ref.read(lessonPlansProvider.notifier).refresh(),
            ref.read(forumsProvider.notifier).refresh(),
          ]);
          ref.invalidate(participatedForumIdsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ==========================================
            // 1. ACCOUNT GREETING CARD
            // ==========================================
            _GreetingBanner(
              greeting: '${_timeGreeting()}, ${_displayFirstName(account)}!',
              account: account,
              classCount: myClassrooms.length,
              planCount: myPlans.length,
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 2. MY CLASSROOMS (TOP PRIORITY)
            // ==========================================
            _SectionHeader(
              icon: Icons.school_outlined,
              title: 'My Classrooms',
              count: myClassrooms.length,
              actionLabel: 'New Class',
              actionIcon: Icons.add,
              onAction: () async {
                final created = await showClassroomFormDialog(context, ref);
                if (created != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ClassroomDetailScreen(classroomId: created.id),
                    ),
                  );
                }
              },
            ),
            if (classroomsAsync.isLoading && myClassrooms.isEmpty)
              const _SectionLoadingCard()
            else if (myClassrooms.isEmpty)
              _EmptySectionCard(
                message: 'You have not created any classrooms yet.',
                buttonLabel: 'Create Classroom',
                onPressed: () async {
                  final created = await showClassroomFormDialog(context, ref);
                  if (created != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ClassroomDetailScreen(classroomId: created.id),
                      ),
                    );
                  }
                },
              )
            else ...[
              ...myClassrooms.take(4).map(
                    (cls) => _ClassroomSummaryTile(
                      classroom: cls,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ClassroomDetailScreen(classroomId: cls.id),
                        ),
                      ),
                    ),
                  ),
              if (myClassrooms.length > 4 && onNavigateToTab != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onNavigateToTab!(1),
                    child: Text('View all ${myClassrooms.length} classes'),
                  ),
                ),
            ],
            const SizedBox(height: 20),

            // ==========================================
            // 3. LESSON PLANS (OWNED / CO-OWNED & SUGGESTED)
            // ==========================================
            _SectionHeader(
              icon: Icons.menu_book_outlined,
              title: 'My Lesson Plans',
              count: myPlans.length,
              actionLabel: 'New Plan',
              actionIcon: Icons.add,
              onAction: () async {
                final created = await showLessonPlanFormDialog(context, ref);
                if (created != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LessonPlanDetailScreen(lessonPlanId: created.id),
                    ),
                  );
                }
              },
            ),
            if (plansAsync.isLoading && myPlans.isEmpty)
              const _SectionLoadingCard()
            else if (myPlans.isEmpty)
              _EmptySectionCard(
                message: 'No owned or co-owned lesson plans yet.',
                buttonLabel: 'Create Lesson Plan',
                onPressed: () async {
                  final created = await showLessonPlanFormDialog(context, ref);
                  if (created != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonPlanDetailScreen(lessonPlanId: created.id),
                      ),
                    );
                  }
                },
              )
            else ...[
              ...myPlans.take(4).map(
                    (plan) => _LessonPlanSummaryTile(
                      plan: plan,
                      badgeText: plan.contributionRoleFor(
                        userId,
                        currentUsername: username,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LessonPlanDetailScreen(lessonPlanId: plan.id),
                        ),
                      ),
                    ),
                  ),
              if (myPlans.length > 4 && onNavigateToTab != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onNavigateToTab!(2),
                    child: Text('View all ${myPlans.length} plans'),
                  ),
                ),
            ],

            if (suggestedPlans.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Suggested in Similar Learning Areas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              ...suggestedPlans.map(
                (plan) => _LessonPlanSummaryTile(
                  plan: plan,
                  isSuggested: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LessonPlanDetailScreen(lessonPlanId: plan.id),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ==========================================
            // 4. RECENT FORUM DISCUSSIONS (LOW-PRIORITY)
            // ==========================================
            _SectionHeader(
              icon: Icons.forum_outlined,
              title: 'Recent Discussions',
              count: relevantForums.length,
              actionLabel: onNavigateToTab != null ? 'All Forums' : null,
              onAction:
                  onNavigateToTab != null ? () => onNavigateToTab!(3) : null,
            ),
            if (relevantForums.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All caught up on your lesson plan discussions.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...relevantForums.map(
                (forum) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      forum.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${forum.threadCount} active ${forum.threadCount == 1 ? 'thread' : 'threads'}',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForumThreadsScreen(forum: forum),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// COMPACT INTERNAL WIDGETS
// =============================================================================

class _GreetingBanner extends StatelessWidget {
  const _GreetingBanner({
    required this.greeting,
    required this.account,
    required this.classCount,
    required this.planCount,
  });

  final String greeting;
  final Account? account;
  final int classCount;
  final int planCount;

  String _roleLabel(Account? account) {
    if (account == null) return 'Educator';
    if (account.roleDisplay.trim().isNotEmpty) {
      return account.roleDisplay.trim();
    }
    switch (account.role) {
      case AccountRole.admin:
        return 'Administrator';
      case AccountRole.checker:
        return 'Reviewer / Checker';
      case AccountRole.teacher:
        return 'Teacher';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roleLabel = _roleLabel(account);
    final school = account?.school.trim() ?? '';
    final initial = (account?.firstName.isNotEmpty == true
            ? account!.firstName[0]
            : (account?.username.isNotEmpty == true
                ? account!.username[0]
                : 'K'))
        .toUpperCase();

    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        school.isNotEmpty ? '$roleLabel • $school' : roleLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              colors.onPrimaryContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatPill(
                  icon: Icons.school_outlined,
                  label: '$classCount ${classCount == 1 ? 'Class' : 'Classes'}',
                ),
                _StatPill(
                  icon: Icons.menu_book_outlined,
                  label:
                      '$planCount ${planCount == 1 ? 'Lesson Plan' : 'Lesson Plans'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final int count;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Badge(
            label: Text('$count'),
            backgroundColor: colors.secondaryContainer,
            textColor: colors.onSecondaryContainer,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.arrow_forward, size: 16),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassroomSummaryTile extends StatelessWidget {
  const _ClassroomSummaryTile({
    required this.classroom,
    required this.onTap,
  });

  final Classroom classroom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (classroom.section.isNotEmpty) 'Sec. ${classroom.section}',
      if (classroom.gradeLevelNames.isNotEmpty)
        classroom.gradeLevelNames.join(', '),
      '${classroom.effectiveStudentCount} students',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.class_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          classroom.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          details.join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LessonPlanSummaryTile extends StatelessWidget {
  const _LessonPlanSummaryTile({
    required this.plan,
    required this.onTap,
    this.badgeText,
    this.isSuggested = false,
  });

  final LessonPlan plan;
  final VoidCallback onTap;
  final String? badgeText;
  final bool isSuggested;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final grades = plan.gradeLevels
        .map((g) => g.gradeLevelName)
        .where((n) => n.isNotEmpty)
        .join(', ');
    final subtitleParts = <String>[
      if (plan.subject.isNotEmpty) plan.subject,
      if (grades.isNotEmpty) grades,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: isSuggested
              ? colors.tertiaryContainer
              : colors.secondaryContainer,
          child: Icon(
            isSuggested ? Icons.lightbulb_outline : Icons.description_outlined,
            color: isSuggested
                ? colors.onTertiaryContainer
                : colors.onSecondaryContainer,
          ),
        ),
        title: Text(
          plan.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitleParts.isNotEmpty
            ? Text(
                subtitleParts.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeText != null && badgeText!.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    label: Text(
                      badgeText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLoadingCard extends StatelessWidget {
  const _SectionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}
