import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/auth_provider.dart';
import '../../curriculum/data/curriculum_models.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../data/classroom_models.dart';
import '../providers/classroom_provider.dart';
import 'classroom_detail_screen.dart';

enum _ClassroomGroupFilter { all, myClasses, otherClasses }

Future<Classroom?> showClassroomFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Classroom? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final schoolCtrl = TextEditingController(text: existing?.schoolName ?? '');
  final sectionCtrl = TextEditingController(text: existing?.section ?? '');
  final syCtrl = TextEditingController(
    text: existing?.schoolYear.isNotEmpty == true
        ? existing!.schoolYear
        : '2026-2027',
  );
  final formKey = GlobalKey<FormState>();

  List<GradeLevel> availableLevels = const [];
  List<LessonPlan> availablePlans = const [];
  try {
    availableLevels = await ref.read(gradeLevelsProvider.future);
  } catch (_) {}
  try {
    availablePlans = await ref.read(lessonPlansProvider.future);
  } catch (_) {}

  if (!context.mounted) return null;

  final selectedGradeIds = <int>{...existing?.gradeLevelIds ?? const []};
  String? selectedLessonPlanId = existing?.lessonPlanId;
  bool isActive = existing?.isActive ?? true;
  bool isSaving = false;

  return showDialog<Classroom>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Create Classroom' : 'Edit Classroom'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Classroom Name (e.g. Grades 1 & 2 Multigrade - Acacia)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: schoolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'School Name (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sectionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Section (e.g. Acacia)',
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
                  if (availableLevels.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Multigrade Levels',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: availableLevels.map((gl) {
                        final selected = selectedGradeIds.contains(gl.id);
                        return FilterChip(
                          label: Text(gl.name),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                selectedGradeIds.add(gl.id);
                              } else {
                                selectedGradeIds.remove(gl.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: availablePlans.any(
                      (p) => p.id == selectedLessonPlanId,
                    )
                        ? selectedLessonPlanId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Active Lesson Plan (for Gradebook)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None selected'),
                      ),
                      ...availablePlans.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                            p.subject.isNotEmpty
                                ? '${p.title} (${p.subject})'
                                : p.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedLessonPlanId = val),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Classroom'),
                      value: isActive,
                      onChanged: (val) => setState(() => isActive = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: isSaving
                ? null
                : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setState(() => isSaving = true);
                    try {
                      final orderedIds = selectedGradeIds.toList()..sort();
                      final names = orderedIds
                          .map(
                            (id) => availableLevels
                                .where((g) => g.id == id)
                                .map((g) => g.name)
                                .firstOrNull,
                          )
                          .whereType<String>()
                          .toList();
                      final selectedPlan = selectedLessonPlanId == null
                          ? null
                          : availablePlans
                              .where((p) => p.id == selectedLessonPlanId)
                              .firstOrNull;

                      final Classroom result;
                      if (existing == null) {
                        result = await ref
                            .read(classroomsProvider.notifier)
                            .createClassroom(
                              name: nameCtrl.text,
                              schoolName: schoolCtrl.text,
                              section: sectionCtrl.text,
                              schoolYear: syCtrl.text,
                              gradeLevelIds: orderedIds,
                              gradeLevelNames: names,
                              lessonPlanId: selectedLessonPlanId,
                              lessonPlanTitle: selectedPlan?.title ?? '',
                            );
                      } else {
                        result = await ref
                            .read(classroomsProvider.notifier)
                            .updateClassroom(
                              classroomId: existing.id,
                              name: nameCtrl.text,
                              schoolName: schoolCtrl.text,
                              section: sectionCtrl.text,
                              schoolYear: syCtrl.text,
                              isActive: isActive,
                              gradeLevelIds: orderedIds,
                              gradeLevelNames: names,
                              lessonPlanId: selectedLessonPlanId,
                              lessonPlanTitle: selectedPlan?.title ?? '',
                            );
                      }
                      if (ctx.mounted) Navigator.pop(ctx, result);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed to save: $e')),
                        );
                      }
                    } finally {
                      if (ctx.mounted) setState(() => isSaving = false);
                    }
                  },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    ),
  );
}

class ClassroomsScreen extends ConsumerStatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  ConsumerState<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends ConsumerState<ClassroomsScreen> {
  final _searchCtrl = TextEditingController();
  _ClassroomGroupFilter _selectedGroup = _ClassroomGroupFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCreatePressed() async {
    final created = await showClassroomFormDialog(context, ref);
    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassroomDetailScreen(classroomId: created.id),
        ),
      );
    }
  }

  bool _isMyClassroom(Classroom cls, int? currentUserId) {
    if (cls.isLocalDraft) return true;
    return currentUserId != null &&
        cls.adviserId != null &&
        cls.adviserId == currentUserId;
  }

  Widget _buildClassroomCard(
    BuildContext context,
    Classroom cls, {
    required bool isAdviser,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitleParts = <String>[
      if (cls.schoolName.isNotEmpty) cls.schoolName,
      if (cls.section.isNotEmpty) 'Section ${cls.section}',
      if (cls.schoolYear.isNotEmpty) 'SY ${cls.schoolYear}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClassroomDetailScreen(classroomId: cls.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isAdviser
                          ? colors.primaryContainer
                          : colors.secondaryContainer,
                      child: Icon(
                        Icons.class_outlined,
                        color: isAdviser
                            ? colors.onPrimaryContainer
                            : colors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cls.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subtitleParts.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitleParts.join(' • '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (cls.adviserName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              isAdviser
                                  ? 'Adviser: ${cls.adviserName} (You)'
                                  : 'Adviser: ${cls.adviserName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isAdviser
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: isAdviser
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: const Icon(
                        Icons.people_outline,
                        size: 16,
                      ),
                      label: Text(
                        '${cls.effectiveStudentCount} ${cls.effectiveStudentCount == 1 ? 'student' : 'students'}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    ...cls.gradeLevelNames.map(
                      (name) => Chip(
                        label: Text(name),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (cls.lessonPlanTitle.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.menu_book_outlined,
                          size: 16,
                        ),
                        label: Text(cls.lessonPlanTitle),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (cls.isPendingSync || cls.isLocalDraft)
                      const Chip(
                        avatar: Icon(Icons.sync, size: 16),
                        label: Text('Pending Sync'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search classrooms by name, school, or section...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(classroomsProvider.notifier)
                              .refresh(search: '');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                ref.read(classroomsProvider.notifier).refresh(search: val);
              },
            ),
          ),
          Expanded(
            child: classroomsAsync.when(
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
                    child: Text(
                      'No classrooms yet. Tap + to create your first class.',
                    ),
                  );
                }

                final myClassrooms = classrooms
                    .where((c) => _isMyClassroom(c, currentUser?.id))
                    .toList();
                final otherClassrooms = classrooms
                    .where((c) => !_isMyClassroom(c, currentUser?.id))
                    .toList();

                final showMine = _selectedGroup == _ClassroomGroupFilter.all ||
                    _selectedGroup == _ClassroomGroupFilter.myClasses;
                final showOther = _selectedGroup == _ClassroomGroupFilter.all ||
                    _selectedGroup == _ClassroomGroupFilter.otherClasses;

                final hasVisibleItems = (showMine && myClassrooms.isNotEmpty) ||
                    (showOther && otherClassrooms.isNotEmpty);

                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text('All (${classrooms.length})'),
                            selected:
                                _selectedGroup == _ClassroomGroupFilter.all,
                            onSelected: (_) => setState(
                              () => _selectedGroup = _ClassroomGroupFilter.all,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(Icons.school_outlined, size: 16),
                            label:
                                Text('My Classrooms (${myClassrooms.length})'),
                            selected: _selectedGroup ==
                                _ClassroomGroupFilter.myClasses,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  _ClassroomGroupFilter.myClasses,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: const Icon(Icons.groups_outlined, size: 16),
                            label: Text(
                              'Other Classrooms (${otherClassrooms.length})',
                            ),
                            selected: _selectedGroup ==
                                _ClassroomGroupFilter.otherClasses,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  _ClassroomGroupFilter.otherClasses,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            ref.read(classroomsProvider.notifier).refresh(),
                        child: !hasVisibleItems
                            ? ListView(
                                padding: const EdgeInsets.all(32),
                                children: const [
                                  Center(
                                    child: Text(
                                      'No classrooms in this category.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                children: [
                                  if (showMine && myClassrooms.isNotEmpty) ...[
                                    _ClassroomGroupHeader(
                                      icon: Icons.school_outlined,
                                      title: 'My Classrooms',
                                      subtitle:
                                          'Classes advised by you & local offline drafts',
                                      count: myClassrooms.length,
                                    ),
                                    ...myClassrooms.map(
                                      (cls) => _buildClassroomCard(
                                        context,
                                        cls,
                                        isAdviser: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (showOther &&
                                      otherClassrooms.isNotEmpty) ...[
                                    _ClassroomGroupHeader(
                                      icon: Icons.groups_outlined,
                                      title: 'Other Classrooms',
                                      subtitle:
                                          'Classes advised by other educators',
                                      count: otherClassrooms.length,
                                    ),
                                    ...otherClassrooms.map(
                                      (cls) => _buildClassroomCard(
                                        context,
                                        cls,
                                        isAdviser: false,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreatePressed,
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
    );
  }
}

class _ClassroomGroupHeader extends StatelessWidget {
  const _ClassroomGroupHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Badge(
            label: Text('$count'),
            backgroundColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ],
      ),
    );
  }
}
