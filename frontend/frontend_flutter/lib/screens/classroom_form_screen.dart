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

    if (_selectedGradeLevelIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one grade level.')),
      );
      return;
    }

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
        await api.updateClassroom(payload);
      }

      if (mounted) {
        ref.read(classroomsProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.classroom == null
                  ? 'Classroom created successfully!'
                  : 'Classroom updated successfully!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save classroom: $e'),
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
    final isEditing = widget.classroom != null;
    final lessonPlansAsync = ref.watch(lessonPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Classroom' : 'Create Classroom'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // Unique hero tag
        onPressed: _isSubmitting ? null : _saveClassroom,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(isEditing ? 'Update Classroom' : 'Create Classroom'),
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

              // --- Lesson Plan Dropdown Selection ---
              lessonPlansAsync.when(
                data: (plans) {
                  return DropdownButtonFormField<int?>(
                    value: _selectedLessonPlanId,
                    decoration: const InputDecoration(
                      labelText: 'Linked Lesson Plan (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...plans.map((plan) {
                        return DropdownMenuItem<int?>(
                          value: plan.lpId,
                          child: Text(plan.lpTitle, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedLessonPlanId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error loading lesson plans: $err'),
              ),
              const SizedBox(height: 16),

              // --- Grade Levels Selection ---
              const Text(
                'Assigned Grade Levels',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(6, (index) {
                  final glId = index + 1;
                  final isSelected = _selectedGradeLevelIds.contains(glId);
                  return FilterChip(
                    label: Text('Grade $glId'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGradeLevelIds.add(glId);
                        } else {
                          _selectedGradeLevelIds.remove(glId);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Classroom'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 80), // Extra space to avoid overlap with FAB
            ],
          ),
        ),
      ),
    );
  }
}
