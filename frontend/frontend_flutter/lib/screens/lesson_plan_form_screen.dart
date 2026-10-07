import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson_plan_model.dart';
import '../models/lesson_grade_level_model.dart';
import '../models/lesson_grading_model.dart';
import '../providers/app_providers.dart';

class LessonPlanFormScreen extends ConsumerStatefulWidget {
  final LessonPlanModel? lessonPlan;
  final bool isCloning;

  const LessonPlanFormScreen({
    super.key, 
    this.lessonPlan, 
    this.isCloning = false,
  });

  @override
  ConsumerState<LessonPlanFormScreen> createState() => _LessonPlanFormScreenState();
}

class _LessonPlanFormScreenState extends ConsumerState<LessonPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _learningAreaController;
  late TextEditingController _primaryLanguageController;
  late TextEditingController _suggestedDemographicController;
  late TextEditingController _learningModelDescController;
  late TextEditingController _intentionsDescController;
  late TextEditingController _notesController;

  List<_GradeLevelFormState> _gradeLevelStates = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final lp = widget.lessonPlan;
    final isCloning = widget.isCloning;

    final initialTitle = lp != null
        ? (isCloning ? '${lp.lpTitle} (Copy)' : lp.lpTitle)
        : '';

    _titleController = TextEditingController(text: initialTitle);
    _learningAreaController = TextEditingController(text: lp?.learningArea ?? '');
    _primaryLanguageController = TextEditingController(text: lp?.primaryLanguage ?? 'English');
    _suggestedDemographicController = TextEditingController(text: lp?.suggestedDemographic ?? '');
    _learningModelDescController = TextEditingController(text: lp?.learningModelDescription ?? '');
    _intentionsDescController = TextEditingController(text: lp?.intentionsDescription ?? '');
    _notesController = TextEditingController(text: lp?.notes ?? '');

    if (lp != null && lp.gradeLevels.isNotEmpty) {
      _gradeLevelStates = lp.gradeLevels
          .map((gl) => _GradeLevelFormState.fromModel(gl, isCloning: isCloning))
          .toList();
    } else {
      _gradeLevelStates = [_GradeLevelFormState(glId: 1)];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _learningAreaController.dispose();
    _primaryLanguageController.dispose();
    _suggestedDemographicController.dispose();
    _learningModelDescController.dispose();
    _intentionsDescController.dispose();
    _notesController.dispose();
    for (var glState in _gradeLevelStates) {
      glState.dispose();
    }
    super.dispose();
  }

  void _addGradeLevel(int glId) {
    if (_gradeLevelStates.any((g) => g.glId == glId)) return;
    setState(() {
      _gradeLevelStates.add(_GradeLevelFormState(glId: glId));
    });
  }

  void _removeGradeLevel(int glId) {
    setState(() {
      final item = _gradeLevelStates.firstWhere((g) => g.glId == glId);
      item.dispose();
      _gradeLevelStates.removeWhere((g) => g.glId == glId);
    });
  }

  Future<void> _saveLessonPlan({bool forceClone = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_gradeLevelStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one grade level breakdown.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final isCloningMode = widget.isCloning || forceClone;
    final compiledGradeLevels = _gradeLevelStates.map((glState) => glState.toModel()).toList();

    // Set lpId to null when creating or cloning to trigger POST endpoint
    final targetLpId = isCloningMode ? null : widget.lessonPlan?.lpId;

    final payload = LessonPlanModel(
      lpId: targetLpId,
      lpTitle: _titleController.text.trim(),
      learningArea: _learningAreaController.text.trim(),
      primaryLanguage: _primaryLanguageController.text.trim(),
      suggestedDemographic: _suggestedDemographicController.text.trim().isEmpty ? null : _suggestedDemographicController.text.trim(),
      learningModelDescription: _learningModelDescController.text.trim().isEmpty ? null : _learningModelDescController.text.trim(),
      intentionsDescription: _intentionsDescController.text.trim().isEmpty ? null : _intentionsDescController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      gradeLevels: compiledGradeLevels,
    );

    try {
      final api = ref.read(apiServiceProvider);
      if (targetLpId == null) {
        await api.createLessonPlan(payload);
      } else {
        await api.updateLessonPlan(payload);
      }

      if (mounted) {
        ref.invalidate(lessonPlansProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCloningMode
                  ? 'Lesson plan cloned successfully!'
                  : widget.lessonPlan == null
                      ? 'Lesson plan created successfully!'
                      : 'Lesson plan updated successfully!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save lesson plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isCloning
        ? 'Clone & Adapt Lesson Plan'
        : (widget.lessonPlan != null ? 'Edit Lesson Plan' : 'Create Lesson Plan');

    final fabLabelText = widget.isCloning
        ? 'Save Cloned Plan'
        : (widget.lessonPlan != null ? 'Update Lesson Plan' : 'Create Lesson Plan');

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          // Non-destructive add: Quick Clone action directly in App Bar when editing existing plan
          if (widget.lessonPlan != null && !widget.isCloning)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Clone as New Plan',
              onPressed: _isSubmitting ? null : () => _saveLessonPlan(forceClone: true),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lessonPlanFormSubmitFab',
        onPressed: _isSubmitting ? null : () => _saveLessonPlan(),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(widget.isCloning ? Icons.copy_all : Icons.save),
        label: Text(fabLabelText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('General Plan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Lesson Plan Title', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _learningAreaController,
                decoration: const InputDecoration(labelText: 'Learning Area (e.g., Mathematics)', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a learning area' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primaryLanguageController,
                decoration: const InputDecoration(labelText: 'Primary Language', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter primary language' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _suggestedDemographicController,
                decoration: const InputDecoration(labelText: 'Suggested Demographic', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _learningModelDescController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Learning Model Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _intentionsDescController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Intentions Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 1.5),

              // --- Grade-Specific Section ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grade Level Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    tooltip: 'Add Grade Level',
                    onSelected: _addGradeLevel,
                    itemBuilder: (context) {
                      return List.generate(6, (i) => i + 1)
                          .where((glId) => !_gradeLevelStates.any((g) => g.glId == glId))
                          .map((glId) => PopupMenuItem(
                                value: glId,
                                child: Text('Add Grade $glId'),
                              ))
                          .toList();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ..._gradeLevelStates.map((glState) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grade ${glState.glId} Breakdown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (_gradeLevelStates.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeGradeLevel(glState.glId),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: glState.contentStandardCtrl,
                          decoration: const InputDecoration(labelText: 'Content Standard', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: glState.performanceStandardCtrl,
                          decoration: const InputDecoration(labelText: 'Performance Standard', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: glState.objectivesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Objectives', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: glState.remediationCtrl,
                          decoration: const InputDecoration(labelText: 'Remediation Guidelines', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: glState.enrichmentCtrl,
                          decoration: const InputDecoration(labelText: 'Enrichment Guidelines', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),

                        // --- Nested Grading Tasks List ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grading Tasks',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  glState.gradingTasks.add(_GradingTaskFormState());
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Task'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...glState.gradingTasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final taskState = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: taskState.taskNameCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Task Name #${idx + 1}',
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (val) {
                                          if (glState.gradingTasks.length > 1 && (val == null || val.trim().isEmpty)) {
                                            return 'Task name required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (glState.gradingTasks.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            taskState.dispose();
                                            glState.gradingTasks.removeAt(idx);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: taskState.taskDescCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Task Description',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: taskState.gradeWeightCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Grade Weight (e.g. 1.0)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (val) {
                                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                                            return 'Invalid decimal';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: taskState.maxScoreCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Max Score',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        validator: (val) {
                                          if (val != null && val.isNotEmpty && int.tryParse(val) == null) {
                                            return 'Invalid integer';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // Material Selection Checkboxes/Chips
                        const Text('Associated Material IDs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Wrap(
                          spacing: 6,
                          children: List.generate(5, (index) {
                            final matId = index + 1;
                            final isSelected = glState.materialIds.contains(matId);
                            return FilterChip(
                              label: Text('Material #$matId'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    glState.materialIds.add(matId);
                                  } else {
                                    glState.materialIds.remove(matId);
                                  }
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradingTaskFormState {
  final int? lgId;
  final TextEditingController taskNameCtrl;
  final TextEditingController taskDescCtrl;
  final TextEditingController gradeWeightCtrl;
  final TextEditingController maxScoreCtrl;

  _GradingTaskFormState({
    this.lgId,
    String? taskName,
    String? taskDescription,
    double? gradeWeight,
    int? maxScore,
  })  : taskNameCtrl = TextEditingController(text: taskName ?? ''),
        taskDescCtrl = TextEditingController(text: taskDescription ?? ''),
        gradeWeightCtrl = TextEditingController(text: gradeWeight?.toString() ?? '1.00'),
        maxScoreCtrl = TextEditingController(text: maxScore?.toString() ?? '100');

  factory _GradingTaskFormState.fromModel(LessonGradingModel model, {bool isCloning = false}) {
    return _GradingTaskFormState(
      lgId: isCloning ? null : model.lgId,
      taskName: model.taskName,
      taskDescription: model.taskDescription,
      gradeWeight: model.gradeWeight,
      maxScore: model.maxScore,
    );
  }

  LessonGradingModel? toModel() {
    final name = taskNameCtrl.text.trim();
    if (name.isEmpty) return null;

    final weight = double.tryParse(gradeWeightCtrl.text.trim()) ?? 1.0;
    final maxScore = int.tryParse(maxScoreCtrl.text.trim()) ?? 100;

    return LessonGradingModel(
      lgId: lgId,
      taskName: name,
      taskDescription: taskDescCtrl.text.trim().isEmpty ? null : taskDescCtrl.text.trim(),
      gradeWeight: weight,
      maxScore: maxScore,
    );
  }

  void dispose() {
    taskNameCtrl.dispose();
    taskDescCtrl.dispose();
    gradeWeightCtrl.dispose();
    maxScoreCtrl.dispose();
  }
}

class _GradeLevelFormState {
  final int glId;
  final TextEditingController contentStandardCtrl;
  final TextEditingController performanceStandardCtrl;
  final TextEditingController objectivesCtrl;
  final TextEditingController remediationCtrl;
  final TextEditingController enrichmentCtrl;

  final List<_GradingTaskFormState> gradingTasks;
  List<int> materialIds;

  _GradeLevelFormState({
    required this.glId,
    String? contentStandard,
    String? performanceStandard,
    String? objectives,
    String? remediation,
    String? enrichment,
    List<_GradingTaskFormState>? gradingTasks,
    List<int>? materialIds,
  })  : contentStandardCtrl = TextEditingController(text: contentStandard ?? ''),
        performanceStandardCtrl = TextEditingController(text: performanceStandard ?? ''),
        objectivesCtrl = TextEditingController(text: objectives ?? ''),
        remediationCtrl = TextEditingController(text: remediation ?? ''),
        enrichmentCtrl = TextEditingController(text: enrichment ?? ''),
        gradingTasks = gradingTasks ?? [_GradingTaskFormState()],
        materialIds = materialIds ?? [];

  factory _GradeLevelFormState.fromModel(LessonGradeLevelModel model, {bool isCloning = false}) {
    return _GradeLevelFormState(
      glId: model.glId,
      contentStandard: model.iContentStandard,
      performanceStandard: model.iPerformanceStandard,
      objectives: model.iObjectives,
      remediation: model.reRemediation,
      enrichment: model.reEnrichment,
      gradingTasks: model.gradingTasks.isNotEmpty
          ? model.gradingTasks.map((gt) => _GradingTaskFormState.fromModel(gt, isCloning: isCloning)).toList()
          : [_GradingTaskFormState()],
      materialIds: List<int>.from(model.materialIds),
    );
  }

  LessonGradeLevelModel toModel() {
    final compiledGradingTasks = gradingTasks
        .map((gt) => gt.toModel())
        .whereType<LessonGradingModel>()
        .toList();

    return LessonGradeLevelModel(
      glId: glId,
      iContentStandard: contentStandardCtrl.text.trim().isEmpty ? null : contentStandardCtrl.text.trim(),
      iPerformanceStandard: performanceStandardCtrl.text.trim().isEmpty ? null : performanceStandardCtrl.text.trim(),
      iObjectives: objectivesCtrl.text.trim().isEmpty ? null : objectivesCtrl.text.trim(),
      reRemediation: remediationCtrl.text.trim().isEmpty ? null : remediationCtrl.text.trim(),
      reEnrichment: enrichmentCtrl.text.trim().isEmpty ? null : enrichmentCtrl.text.trim(),
      gradingTasks: compiledGradingTasks,
      materialIds: materialIds,
    );
  }

  void dispose() {
    contentStandardCtrl.dispose();
    performanceStandardCtrl.dispose();
    objectivesCtrl.dispose();
    remediationCtrl.dispose();
    enrichmentCtrl.dispose();
    for (var task in gradingTasks) {
      task.dispose();
    }
  }
}
