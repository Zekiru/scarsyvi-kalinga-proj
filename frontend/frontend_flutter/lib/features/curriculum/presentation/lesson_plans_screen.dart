import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/auth_provider.dart';
import '../data/curriculum_models.dart';
import '../providers/curriculum_provider.dart';
import 'lesson_plan_detail_screen.dart';
import 'widgets/lesson_plan_card.dart';
import 'widgets/lesson_plan_form_dialog.dart';

enum _LessonPlanGroupFilter { all, own, contributed, resourceCenter }

class LessonPlansScreen extends ConsumerStatefulWidget {
  const LessonPlansScreen({super.key});

  @override
  ConsumerState<LessonPlansScreen> createState() => _LessonPlansScreenState();
}

class _LessonPlansScreenState extends ConsumerState<LessonPlansScreen> {
  final _searchCtrl = TextEditingController();
  _LessonPlanGroupFilter _selectedGroup = _LessonPlanGroupFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCreatePressed() async {
    final created = await showLessonPlanFormDialog(context, ref);
    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonPlanDetailScreen(lessonPlanId: created.id),
        ),
      );
    }
  }

  void _openPlan(LessonPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPlanDetailScreen(lessonPlanId: plan.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(lessonPlansProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.id;
    final username = currentUser?.username;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search lesson plans by title or learning area...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(lessonPlansProvider.notifier)
                              .refresh(search: '');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                ref.read(lessonPlansProvider.notifier).refresh(search: val);
              },
            ),
          ),
          Expanded(
            child: plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load lesson plans: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(lessonPlansProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return const Center(
                    child: Text('No lesson plans yet. Tap + to create one.'),
                  );
                }

                final ownPlans = <LessonPlan>[];
                final contributedPlans = <LessonPlan>[];
                final resourceCenterPlans = <LessonPlan>[];

                for (final plan in plans) {
                  if (plan.isCreatedBy(userId, currentUsername: username)) {
                    ownPlans.add(plan);
                  } else if (plan.isContributedBy(
                    userId,
                    currentUsername: username,
                  )) {
                    contributedPlans.add(plan);
                  } else {
                    resourceCenterPlans.add(plan);
                  }
                }

                final showOwn = _selectedGroup == _LessonPlanGroupFilter.all ||
                    _selectedGroup == _LessonPlanGroupFilter.own;
                final showContributed =
                    _selectedGroup == _LessonPlanGroupFilter.all ||
                        _selectedGroup == _LessonPlanGroupFilter.contributed;
                final showResources =
                    _selectedGroup == _LessonPlanGroupFilter.all ||
                        _selectedGroup == _LessonPlanGroupFilter.resourceCenter;

                final hasVisibleItems = (showOwn && ownPlans.isNotEmpty) ||
                    (showContributed && contributedPlans.isNotEmpty) ||
                    (showResources && resourceCenterPlans.isNotEmpty);

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
                            label: Text('All (${plans.length})'),
                            selected:
                                _selectedGroup == _LessonPlanGroupFilter.all,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _LessonPlanGroupFilter.all,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(Icons.person_outline, size: 16),
                            label: Text('My Plans (${ownPlans.length})'),
                            selected:
                                _selectedGroup == _LessonPlanGroupFilter.own,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _LessonPlanGroupFilter.own,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(
                              Icons.group_work_outlined,
                              size: 16,
                            ),
                            label: Text(
                              'Contributed (${contributedPlans.length})',
                            ),
                            selected: _selectedGroup ==
                                _LessonPlanGroupFilter.contributed,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  _LessonPlanGroupFilter.contributed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(
                              Icons.public_outlined,
                              size: 16,
                            ),
                            label: Text(
                              'Resource Center (${resourceCenterPlans.length})',
                            ),
                            selected: _selectedGroup ==
                                _LessonPlanGroupFilter.resourceCenter,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  _LessonPlanGroupFilter.resourceCenter,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            ref.read(lessonPlansProvider.notifier).refresh(),
                        child: !hasVisibleItems
                            ? ListView(
                                padding: const EdgeInsets.all(32),
                                children: const [
                                  Center(
                                    child: Text(
                                      'No lesson plans in this category.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                children: [
                                  if (showOwn && ownPlans.isNotEmpty) ...[
                                    _GroupHeader(
                                      icon: Icons.person_outline,
                                      title: 'My Lesson Plans',
                                      subtitle:
                                          'Created by you & local offline drafts',
                                      count: ownPlans.length,
                                    ),
                                    ...ownPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          currentUserId: userId,
                                          currentUsername: username,
                                          onTap: () => _openPlan(plan),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (showContributed &&
                                      contributedPlans.isNotEmpty) ...[
                                    _GroupHeader(
                                      icon: Icons.group_work_outlined,
                                      title: 'Contributed Plans',
                                      subtitle:
                                          'Assigned as checker or co-author',
                                      count: contributedPlans.length,
                                    ),
                                    ...contributedPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          currentUserId: userId,
                                          currentUsername: username,
                                          roleBadge: plan.contributionRoleFor(
                                            userId,
                                            currentUsername: username,
                                          ),
                                          onTap: () => _openPlan(plan),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (showResources &&
                                      resourceCenterPlans.isNotEmpty) ...[
                                    _GroupHeader(
                                      icon: Icons.public_outlined,
                                      title: 'Resource Center',
                                      subtitle:
                                          'Shared plans created by other educators',
                                      count: resourceCenterPlans.length,
                                    ),
                                    ...resourceCenterPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          currentUserId: userId,
                                          currentUsername: username,
                                          onTap: () => _openPlan(plan),
                                        ),
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
        onPressed: _onCreatePressed,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
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
