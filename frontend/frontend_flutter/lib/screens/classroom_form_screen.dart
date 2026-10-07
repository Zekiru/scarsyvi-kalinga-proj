import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classroom_model.dart';
import '../providers/app_providers.dart';

class ClassroomFormScreen extends ConsumerStatefulWidget {
  final ClassroomModel? classroom; // Null for create, non-null for edit

  const ClassroomFormScreen({super.key, this.classroom});

  @override
  ConsumerState<ClassroomFormScreen> createState() => _ClassroomFormScreenState();
}

class _ClassroomFormScreenState extends ConsumerState<ClassroomFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _schoolNameController;
  late TextEditingController _sectionController;
  late TextEditingController _schoolYearController;
  bool _isActive = true;
  int? _selectedLessonPlanId;
  List<int> _selectedGradeLevelIds = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.classroom;
    _nameController = TextEditingController(text: c?.name ?? '');
    _schoolNameController = TextEditingController(text: c?.schoolName ?? '');
    _sectionController = TextEditingController(text: c?.section ?? '');
    _schoolYearController = TextEditingController(text: c?.schoolYear ?? '2025-2026');
    _isActive = c?.isActive ?? true;
    _selectedLessonPlanId = c?.lessonPlanId ?? c?.lessonPlan?.lpId;
    _selectedGradeLevelIds = c?.gradeLevelIds.isNotEmpty == true
        ? List.from(c!.gradeLevelIds)
        : c?.gradeLevels.map((gl) => gl.glId).toList() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolNameController.dispose();
    _sectionController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }

  Future<void> _saveClassroom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = ClassroomModel(
      classroomId: widget.classroom?.classroomId,
      name: _nameController.text.trim(),
      schoolName: _schoolNameController.text.trim(),
      section: _sectionController.text.trim().isEmpty ? null : _sectionController.text.trim(),
      schoolYear: _schoolYearController.text.trim(),
      isActive: _isActive,
      adviser: widget.classroom?.adviser,
      gradeLevelIds: _selectedGradeLevelIds,
      lessonPlanId: _selectedLessonPlanId,
      students: widget.classroom?.students ?? [],
    );

    try {
      final api = ref.read(apiServiceProvider);
      if (widget.classroom?.classroomId == null) {
        await api.createClassroom(payload);
      } else {
        // Implement api.updateClassroom(payload) as needed
      }

      if (mounted) {
        ref.read(classroomsProvider.notifier).refresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save classroom: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.classroom != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Classroom' : 'Create Classroom'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Classroom Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(labelText: 'School Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a school name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sectionController,
                decoration: const InputDecoration(labelText: 'Section (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolYearController,
                decoration: const InputDecoration(labelText: 'School Year', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter school year' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Classroom'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveClassroom,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(isEditing ? 'Update Classroom' : 'Create Classroom'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
