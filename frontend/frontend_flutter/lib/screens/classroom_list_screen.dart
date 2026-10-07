import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'classroom_detail_screen.dart';

class ClassroomListScreen extends ConsumerWidget {
  const ClassroomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multigrade Classrooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(classroomsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: classroomsAsync.when(
        data: (classrooms) {
          if (classrooms.isEmpty) {
            return const Center(child: Text('No classrooms found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: classrooms.length,
            itemBuilder: (context, index) {
              final classroom = classrooms[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    classroom.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('${classroom.schoolName} • S.Y. ${classroom.schoolYear}'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: classroom.gradeLevels.map((gl) {
                          return Chip(
                            label: Text(gl.gradeLevelName, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassroomDetailScreen(classroom: classroom),
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
    );
  }
}
