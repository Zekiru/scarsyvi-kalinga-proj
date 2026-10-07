import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson_plan_model.dart';
import '../models/lesson_grade_level_model.dart';
import '../providers/app_providers.dart';

class LessonPlanFormScreen extends ConsumerStatefulWidget {
  final LessonPlanModel? lessonPlan;

  const LessonPlanFormScreen({super.key, this.lessonPlan});

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
    _titleController = TextEditingController(text: lp?.lpTitle ?? '');
    _learningAreaController = TextEditingController(text: lp?.learningArea ?? '');
    _primaryLanguageController = TextEditingController(text: lp?.primaryLanguage ?? 'English');
    _suggestedDemographicController = TextEditingController(text: lp?.suggestedDemographic ?? '');
    _learningModelDescController = TextEditingController(text: lp?.learningModelDescription ?? '');
    _intentionsDescController = TextEditingController(text: lp?.intentionsDescription ?? '');
    _notesController = TextEditingController(text: lp?.notes ?? '');

    if (lp != null && lp.gradeLevels.isNotEmpty) {
      _gradeLevelStates = lp.gradeLevels.map((gl) => _GradeLevelFormState.fromModel(gl)).toList();
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

  Future<void> _saveLessonPlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gradeLevelStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one grade level breakdown.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final compiledGradeLevels = _gradeLevelStates.map((glState) => glState.toModel()).toList();

    final payload = LessonPlanModel(
      lpId: widget.lessonPlan?.lpId,
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
      if (widget.lessonPlan?.lpId == null) {
        await api.createLessonPlan(payload);
      } else {
        await api.updateLessonPlan(payload);
      }

      if (mounted) {
        ref.invalidate(lessonPlansProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lessonPlan == null
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
    final isEditing = widget.lessonPlan != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Lesson Plan' : 'Create Lesson Plan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // Unique hero tag
        onPressed: _isSubmitting ? null : _saveLessonPlan,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(isEditing ? 'Update Lesson Plan' : 'Create Lesson Plan'),
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

              // Sub-forms for each grade level
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
                        const SizedBox(height: 8),

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

              const SizedBox(height: 80), // Extra space to avoid overlap with FAB
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeLevelFormState {
  final int glId;
  final TextEditingController contentStandardCtrl;
  final TextEditingController performanceStandardCtrl;
  final TextEditingController objectivesCtrl;
  final TextEditingController remediationCtrl;
  final TextEditingController enrichmentCtrl;
  List<int> materialIds;

  _GradeLevelFormState({
    required this.glId,
    String? contentStandard,
    String? performanceStandard,
    String? objectives,
    String? remediation,
    String? enrichment,
    List<int>? materialIds,
  })  : contentStandardCtrl = TextEditingController(text: contentStandard ?? ''),
        performanceStandardCtrl = TextEditingController(text: performanceStandard ?? ''),
        objectivesCtrl = TextEditingController(text: objectives ?? ''),
        remediationCtrl = TextEditingController(text: remediation ?? ''),
        enrichmentCtrl = TextEditingController(text: enrichment ?? ''),
        materialIds = materialIds ?? [];

  factory _GradeLevelFormState.fromModel(LessonGradeLevelModel model) {
    return _GradeLevelFormState(
      glId: model.glId,
      contentStandard: model.iContentStandard,
      performanceStandard: model.iPerformanceStandard,
      objectives: model.iObjectives,
      remediation: model.reRemediation,
      enrichment: model.reEnrichment,
      materialIds: List<int>.from(model.materialIds),
    );
  }

  LessonGradeLevelModel toModel() {
    return LessonGradeLevelModel(
      glId: glId,
      iContentStandard: contentStandardCtrl.text.trim().isEmpty ? null : contentStandardCtrl.text.trim(),
      iPerformanceStandard: performanceStandardCtrl.text.trim().isEmpty ? null : performanceStandardCtrl.text.trim(),
      iObjectives: objectivesCtrl.text.trim().isEmpty ? null : objectivesCtrl.text.trim(),
      reRemediation: remediationCtrl.text.trim().isEmpty ? null : remediationCtrl.text.trim(),
      reEnrichment: enrichmentCtrl.text.trim().isEmpty ? null : enrichmentCtrl.text.trim(),
      materialIds: materialIds,
    );
  }

  void dispose() {
    contentStandardCtrl.dispose();
    performanceStandardCtrl.dispose();
    objectivesCtrl.dispose();
    remediationCtrl.dispose();
    enrichmentCtrl.dispose();
  }
}
