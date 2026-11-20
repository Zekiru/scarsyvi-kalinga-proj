import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/curriculum_provider.dart';
import 'lesson_plan_detail_screen.dart';
import 'widgets/create_lesson_plan_dialog.dart';
import 'widgets/lesson_plan_card.dart';

class LessonPlansScreen extends ConsumerStatefulWidget {
  const LessonPlansScreen({super.key});

  @override
  ConsumerState<LessonPlansScreen> createState() => _LessonPlansScreenState();
}

class _LessonPlansScreenState extends ConsumerState<LessonPlansScreen> {
  final _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(lessonPlansProvider);

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
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(lessonPlansProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: plans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return LessonPlanCard(
                        plan: plan,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LessonPlanDetailScreen(lessonPlanId: plan.id),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreatePressed,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}
