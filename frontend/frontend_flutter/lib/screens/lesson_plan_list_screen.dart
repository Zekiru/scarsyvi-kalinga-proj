import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'lesson_plan_detail_screen.dart';
import 'lesson_plan_form_screen.dart';

class LessonPlanListScreen extends ConsumerWidget {
  const LessonPlanListScreen({super.key});

  Future<void> _deleteLessonPlan(BuildContext context, WidgetRef ref, int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson Plan'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(apiServiceProvider).deleteLessonPlan(id);
        ref.invalidate(lessonPlansProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson plan deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete lesson plan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonPlansAsync = ref.watch(lessonPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Curriculum & Lesson Plans')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LessonPlanFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Edit Plan',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LessonPlanFormScreen(lessonPlan: plan),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Plan',
                              onPressed: () {
                                if (plan.lpId != null) {
                                  _deleteLessonPlan(context, ref, plan.lpId!, plan.lpTitle);
                                }
                              },
                            ),
                          ],
                        ),
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
