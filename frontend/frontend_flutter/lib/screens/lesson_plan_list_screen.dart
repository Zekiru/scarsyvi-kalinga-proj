import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

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
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        title: Text(plan.lpTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${plan.learningArea} • ${plan.primaryLanguage}'),
                        children: [
                          if (plan.notes != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text('Notes: ${plan.notes}'),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Grade Levels Configured: ${plan.gradeLevels.length}'),
                          ),
                        ],
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
