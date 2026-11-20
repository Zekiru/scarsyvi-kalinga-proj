import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

/// Displays LessonGrading tasks (`lg_id`, `lesson_grade_level`, `task_name`,
/// `task_description`, `grade_weight`, `max_score`).
class LessonGradingsTab extends ConsumerStatefulWidget {
  const LessonGradingsTab({super.key, required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  ConsumerState<LessonGradingsTab> createState() => _LessonGradingsTabState();
}

class _LessonGradingsTabState extends ConsumerState<LessonGradingsTab> {
  String? _selectedLglFilter;

  @override
  Widget build(BuildContext context) {
    final allTasks = widget.plan.gradings;
    final filteredTasks = _selectedLglFilter == null
        ? allTasks
        : allTasks
            .where((t) => t.lessonGradeLevelId == _selectedLglFilter)
            .toList();

    return Scaffold(
      body: allTasks.isEmpty
          ? const Center(child: Text('No assessment / grading tasks defined yet.'))
          : Column(
              children: [
                if (widget.plan.gradeLevels.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All Grades'),
                            selected: _selectedLglFilter == null,
                            onSelected: (_) =>
                                setState(() => _selectedLglFilter = null),
                          ),
                          ...widget.plan.gradeLevels.map(
                            (gl) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(
                                  gl.gradeLevelName.isNotEmpty
                                      ? gl.gradeLevelName
                                      : 'Grade ${gl.gradeLevelId}',
                                ),
                                selected: _selectedLglFilter == gl.id,
                                onSelected: (_) =>
                                    setState(() => _selectedLglFilter = gl.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final task = filteredTasks[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.taskName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (task.isPendingSync)
                                    const Chip(label: Text('Queued')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (task.gradeLevelName.isNotEmpty)
                                    Chip(
                                      label: Text(task.gradeLevelName),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (task.gradeWeight > 0)
                                    Chip(
                                      avatar: const Icon(Icons.percent, size: 14),
                                      label: Text(
                                        'Weight: ${task.gradeWeight.toStringAsFixed(0)}%',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (task.maxScore > 0)
                                    Chip(
                                      avatar: const Icon(Icons.grade_outlined, size: 14),
                                      label: Text('Max Score: ${task.maxScore} pts'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              if (task.taskDescription.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(task.taskDescription),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              onPressed: () => _addGradingDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addGradingDialog(BuildContext context, WidgetRef ref) async {
    if (widget.plan.gradeLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach a Grade Level first before adding grading tasks.'),
        ),
      );
      return;
    }

    LessonGradeLevel selectedGrade = widget.plan.gradeLevels.first;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '40');
    final maxScoreCtrl = TextEditingController(text: '10');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Grading Task'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LessonGradeLevel>(
                  initialValue: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level (lesson_grade_level)',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.plan.gradeLevels
                      .map(
                        (g) => DropdownMenuItem<LessonGradeLevel>(
                          value: g,
                          child: Text(
                            g.gradeLevelName.isNotEmpty
                                ? g.gradeLevelName
                                : 'Grade ${g.gradeLevelId}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedGrade = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Task Name (e.g. Pagsasanay sa Addition)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grade Weight (%)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxScoreCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Score',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Task Description / Instructions',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(curriculumRepositoryProvider).addLessonGrading(
                      lessonPlanId: widget.plan.id,
                      lessonGradeLevelId: selectedGrade.id,
                      gradeLevelName: selectedGrade.gradeLevelName,
                      taskName: nameCtrl.text,
                      taskDescription: descCtrl.text,
                      gradeWeight: double.tryParse(weightCtrl.text) ?? 0,
                      maxScore: int.tryParse(maxScoreCtrl.text) ?? 10,
                    );
                ref.read(syncStatusProvider.notifier).refreshCounts();
                ref.invalidate(lessonPlanDetailProvider(widget.plan.id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
