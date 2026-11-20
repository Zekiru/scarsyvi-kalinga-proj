import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../data/curriculum_models.dart';
import '../../data/curriculum_repository.dart';
import '../../providers/curriculum_provider.dart';

/// Renders LessonFlow items (`lf_id`, `lesson_grade_level`, `time_minutes`, `stage`, `description`)
/// as a multi-grade table on wide viewports and grouped/filtered cards on narrow screens.
class LessonFlowsTab extends ConsumerStatefulWidget {
  const LessonFlowsTab({super.key, required this.plan, required this.canEdit});

  final LessonPlan plan;
  final bool canEdit;

  @override
  ConsumerState<LessonFlowsTab> createState() => _LessonFlowsTabState();
}

class _LessonFlowsTabState extends ConsumerState<LessonFlowsTab> {
  String? _selectedLglFilter;

  @override
  Widget build(BuildContext context) {
    final allSteps = [...widget.plan.flows]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    final filteredSteps = _selectedLglFilter == null
        ? allSteps
        : allSteps
            .where((s) => s.lessonGradeLevelId == _selectedLglFilter)
            .toList();

    return Scaffold(
      body: allSteps.isEmpty
          ? const Center(child: Text('No lesson flow steps defined yet.'))
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 700 &&
                          widget.plan.gradeLevels.length >= 2 &&
                          _selectedLglFilter == null) {
                        return _MultiGradeFlowTable(
                          plan: widget.plan,
                          steps: filteredSteps,
                        );
                      }
                      return _FlowCardList(steps: filteredSteps);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              onPressed: () =>
                  _addFlowDialog(context, ref, allSteps.length + 1),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addFlowDialog(
    BuildContext context,
    WidgetRef ref,
    int nextOrder,
  ) async {
    if (widget.plan.gradeLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach a Grade Level first before adding flow steps.'),
        ),
      );
      return;
    }

    LessonGradeLevel selectedGrade = widget.plan.gradeLevels.first;
    final stageCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '10');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Lesson Flow Step'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LessonGradeLevel>(
                  value: selectedGrade,
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
                  controller: stageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Stage (e.g. Motivation, Instruction, Review)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Activity Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Time (minutes)',
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
                if (stageCtrl.text.trim().isEmpty) return;
                await ref.read(curriculumRepositoryProvider).addLessonFlow(
                      lessonPlanId: widget.plan.id,
                      lessonGradeLevelId: selectedGrade.id,
                      gradeLevelName: selectedGrade.gradeLevelName,
                      stepOrder: nextOrder,
                      stage: stageCtrl.text,
                      description: descCtrl.text,
                      timeMinutes: int.tryParse(minsCtrl.text) ?? 10,
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

class _MultiGradeFlowTable extends StatelessWidget {
  const _MultiGradeFlowTable({required this.plan, required this.steps});

  final LessonPlan plan;
  final List<LessonFlow> steps;

  @override
  Widget build(BuildContext context) {
    final grades = plan.gradeLevels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            dataRowMaxHeight: double.infinity,
            columns: [
              const DataColumn(label: Text('Time')),
              const DataColumn(label: Text('Stage')),
              ...grades.map(
                (g) => DataColumn(
                  label: Text(
                    (g.gradeLevelName.isNotEmpty
                            ? g.gradeLevelName
                            : 'Grade ${g.gradeLevelId}')
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            rows: steps.map((step) {
              return DataRow(
                cells: [
                  DataCell(Text('${step.timeMinutes} min')),
                  DataCell(
                    SizedBox(
                      width: 140,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          step.stage,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  ...grades.map((g) {
                    final matches = step.lessonGradeLevelId == null ||
                        step.lessonGradeLevelId == g.id;
                    return DataCell(
                      SizedBox(
                        width: 260,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(matches ? step.description : '—'),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _FlowCardList extends StatelessWidget {
  const _FlowCardList({required this.steps});

  final List<LessonFlow> steps;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final step = steps[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${step.timeMinutes}m'),
            ),
            title: Text(step.stage,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.gradeLevelName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(step.gradeLevelName),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(step.description),
              ],
            ),
            trailing: step.isPendingSync ? const Chip(label: Text('Queued')) : null,
          ),
        );
      },
    );
  }
}
