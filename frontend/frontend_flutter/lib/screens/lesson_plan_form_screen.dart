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

  List<LessonGradeLevelModel> _gradeLevels = [];
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
    _gradeLevels = lp?.gradeLevels != null ? List.from(lp!.gradeLevels) : [];
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
    super.dispose();
  }

  Future<void> _saveLessonPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = LessonPlanModel(
      lpId: widget.lessonPlan?.lpId,
      lpTitle: _titleController.text.trim(),
      learningArea: _learningAreaController.text.trim(),
      primaryLanguage: _primaryLanguageController.text.trim(),
      suggestedDemographic: _suggestedDemographicController.text.trim().isEmpty ? null : _suggestedDemographicController.text.trim(),
      learningModelDescription: _learningModelDescController.text.trim().isEmpty ? null : _learningModelDescController.text.trim(),
      intentionsDescription: _intentionsDescController.text.trim().isEmpty ? null : _intentionsDescController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      gradeLevels: _gradeLevels,
    );

    try {
      // Implement API endpoint call (create or update lesson plan)
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save lesson plan: $e')),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Lesson Plan Title', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _learningAreaController,
                decoration: const InputDecoration(labelText: 'Learning Area (e.g. Mathematics)', border: OutlineInputBorder()),
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
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveLessonPlan,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(isEditing ? 'Update Lesson Plan' : 'Create Lesson Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
