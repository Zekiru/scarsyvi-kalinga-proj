import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/classroom_models.dart';
import '../providers/classroom_provider.dart';
import 'classroom_detail_screen.dart';

class ClassroomsScreen extends ConsumerWidget {
  const ClassroomsScreen({super.key});

  Future<void> _showCreateClassroomDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final syCtrl = TextEditingController(text: '2026-2027');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<Classroom>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Classroom'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class / Subject Name (e.g. Grade 7 Science)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sectionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Section (e.g. Rizal)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: syCtrl,
                        decoration: const InputDecoration(
                          labelText: 'School Year',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Room Location (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final classroom = await ref
                  .read(classroomsProvider.notifier)
                  .createClassroom(
                    name: nameCtrl.text,
                    section: sectionCtrl.text,
                    schoolYear: syCtrl.text,
                  );
              if (ctx.mounted) Navigator.pop(ctx, classroom);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassroomDetailScreen(classroomId: created.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      body: classroomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load classrooms: $err'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(classroomsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (classrooms) {
          if (classrooms.isEmpty) {
            return const Center(
              child: Text('No classrooms yet. Tap + to create your first class.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(classroomsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: classrooms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cls = classrooms[index];
                final subtitleParts = <String>[
                  if (cls.section.isNotEmpty) 'Section ${cls.section}',
                  if (cls.schoolYear.isNotEmpty) 'SY ${cls.schoolYear}',
                  '${cls.students.length} students',
                ];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.class_outlined),
                    ),
                    title: Text(
                      cls.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(subtitleParts.join(' • ')),
                    trailing: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (cls.isPendingSync || cls.isLocalDraft)
                          const Chip(
                            label: Text('Queued'),
                            avatar: Icon(Icons.schedule, size: 16),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ClassroomDetailScreen(classroomId: cls.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateClassroomDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
    );
  }
}
