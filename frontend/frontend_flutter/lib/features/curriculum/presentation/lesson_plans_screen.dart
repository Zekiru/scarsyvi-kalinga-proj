import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/auth_provider.dart';
import '../data/curriculum_models.dart';
import '../providers/curriculum_provider.dart';
import 'lesson_plan_detail_screen.dart';
import 'widgets/create_lesson_plan_dialog.dart';
import 'widgets/lesson_plan_card.dart';

enum _LessonPlanGroupFilter {
  all,
  own,
  contributed,
  resourceCenter,
}

class LessonPlansScreen extends ConsumerStatefulWidget {
  const LessonPlansScreen({super.key});

  @override
  ConsumerState<LessonPlansScreen> createState() => _LessonPlansScreenState();
}

class _LessonPlansScreenState extends ConsumerState<LessonPlansScreen> {
  final _searchCtrl = TextEditingController();
  _LessonPlanGroupFilter _groupFilter = _LessonPlanGroupFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCreatePressed() async {
    final created = await showCreateLessonPlanDialog(context, ref);
    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonPlanDetailScreen(lessonPlanId: created.id),
        ),
      );
    }
  }

  void _openDetail(LessonPlan plan) {
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
                  if (plan.isCreatedBy(userId)) {
                    ownPlans.add(plan);
                  } else if (plan.isContributedBy(userId)) {
                    contributedPlans.add(plan);
                  } else {
                    resourceCenterPlans.add(plan);
                  }
                }

                final showOwn = (_groupFilter == _LessonPlanGroupFilter.all ||
                        _groupFilter == _LessonPlanGroupFilter.own) &&
                    ownPlans.isNotEmpty;
                final showContributed =
                    (_groupFilter == _LessonPlanGroupFilter.all ||
                            _groupFilter ==
                                _LessonPlanGroupFilter.contributed) &&
                        contributedPlans.isNotEmpty;
                final showResourceCenter =
                    (_groupFilter == _LessonPlanGroupFilter.all ||
                            _groupFilter ==
                                _LessonPlanGroupFilter.resourceCenter) &&
                        resourceCenterPlans.isNotEmpty;

                final hasAnyVisible =
                    showOwn || showContributed || showResourceCenter;

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
                                _groupFilter == _LessonPlanGroupFilter.all,
                            onSelected: (_) => setState(
                              () => _groupFilter = _LessonPlanGroupFilter.all,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text('My Plans (${ownPlans.length})'),
                            selected:
                                _groupFilter == _LessonPlanGroupFilter.own,
                            onSelected: (_) => setState(
                              () => _groupFilter = _LessonPlanGroupFilter.own,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(
                              'Contributed (${contributedPlans.length})',
                            ),
                            selected: _groupFilter ==
                                _LessonPlanGroupFilter.contributed,
                            onSelected: (_) => setState(
                              () => _groupFilter =
                                  _LessonPlanGroupFilter.contributed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(
                              'Resource Center (${resourceCenterPlans.length})',
                            ),
                            selected: _groupFilter ==
                                _LessonPlanGroupFilter.resourceCenter,
                            onSelected: (_) => setState(
                              () => _groupFilter =
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
                        child: !hasAnyVisible
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
                                  if (showOwn) ...[
                                    _GroupSectionHeader(
                                      icon: Icons.person_outline,
                                      title: 'My Lesson Plans',
                                      subtitle:
                                          'Created by you or saved as local drafts',
                                      count: ownPlans.length,
                                    ),
                                    const SizedBox(height: 8),
                                    ...ownPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          onTap: () => _openDetail(plan),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (showContributed) ...[
                                    _GroupSectionHeader(
                                      icon: Icons.group_work_outlined,
                                      title: 'Contributed Plans',
                                      subtitle:
                                          'Plans where you are a checker or co-author',
                                      count: contributedPlans.length,
                                    ),
                                    const SizedBox(height: 8),
                                    ...contributedPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          roleBadge:
                                              plan.contributionRoleFor(userId),
                                          onTap: () => _openDetail(plan),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (showResourceCenter) ...[
                                    _GroupSectionHeader(
                                      icon: Icons.public,
                                      title: 'Resource Center',
                                      subtitle:
                                          'Shared lesson plans created by other educators',
                                      count: resourceCenterPlans.length,
                                    ),
                                    const SizedBox(height: 8),
                                    ...resourceCenterPlans.map(
                                      (plan) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: LessonPlanCard(
                                          plan: plan,
                                          onTap: () => _openDetail(plan),
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

class _GroupSectionHeader extends StatelessWidget {
  const _GroupSectionHeader({
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
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
          CircleAvatar(
            radius: 13,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
