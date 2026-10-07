import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'lesson_plan_detail_screen.dart';

class LessonPlanListScreen extends ConsumerWidget {
  const LessonPlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonPlansAsync = ref.watch(lessonPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Curriculum & Lesson Plans')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search title, area, or demographic...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(lessonPlanSearchQueryProvider.notifier).updateQuery(val);
              },
            ),
          ),
          Expanded(
            child: lessonPlansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return const Center(child: Text('No lesson plans found.'));
                }
                return ListView.builder(
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final gradeLevelsText = plan.gradeLevels.isEmpty
                        ? 'None specified'
                        : plan.gradeLevels
                            .map((gl) => gl.gradeLevelName ?? 'GL ${gl.glId}')
                            .join(', ');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          plan.lpTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${plan.learningArea} • ${plan.primaryLanguage}\nGrade levels: $gradeLevelsText',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonPlanDetailScreen(
                                lessonPlan: plan,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
