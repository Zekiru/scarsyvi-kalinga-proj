import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/classroom_models.dart';
import '../data/classroom_repository.dart';

final classroomsProvider =
    AsyncNotifierProvider<ClassroomsNotifier, List<Classroom>>(
  ClassroomsNotifier.new,
);

class ClassroomsNotifier extends AsyncNotifier<List<Classroom>> {
  @override
  Future<List<Classroom>> build() async {
    final repo = ref.watch(classroomRepositoryProvider);
    final cached = repo.getCachedClassrooms();

    if (cached.isNotEmpty) {
      Future.microtask(refresh);
      return cached;
    }
    return repo.fetchClassrooms();
  }

  Future<void> refresh() async {
    final repo = ref.read(classroomRepositoryProvider);
    try {
      final fresh = await repo.fetchClassrooms();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<Classroom> createClassroom({
    required String name,
    String schoolName = '',
    String section = '',
    String schoolYear = '',
    List<int> gradeLevelIds = const [],
    String? lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(classroomRepositoryProvider);

    final created = await repo.createClassroom(
      name: name,
      schoolName: schoolName,
      section: section,
      schoolYear: schoolYear,
      gradeLevelIds: gradeLevelIds,
      lessonPlanId: lessonPlanId,
      lessonPlanTitle: lessonPlanTitle,
      adviserId: user?.id,
      adviserName: user?.username ?? '',
    );

    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData([created, ...current]);
    return created;
  }
}

final classroomDetailProvider =
    FutureProvider.family<Classroom, String>((ref, id) async {
  return ref.watch(classroomRepositoryProvider).fetchClassroomDetail(id);
});

class RosterQuery {
  const RosterQuery({
    required this.classroomId,
    this.ordering = 'last_name',
  });

  final String classroomId;
  final String ordering;

  @override
  bool operator ==(Object other) =>
      other is RosterQuery &&
      other.classroomId == classroomId &&
      other.ordering == ordering;

  @override
  int get hashCode => Object.hash(classroomId, ordering);
}

final classroomRosterProvider =
    FutureProvider.family<List<Student>, RosterQuery>((ref, query) async {
  return ref.watch(classroomRepositoryProvider).fetchClassroomStudents(
        query.classroomId,
        ordering: query.ordering,
      );
});

final classroomAttendanceSessionsProvider =
    FutureProvider.family<List<AttendanceSession>, String>(
  (ref, classroomId) async {
    return ref
        .watch(classroomRepositoryProvider)
        .fetchAttendanceSessions(classroomId);
  },
);

final classroomGradesProvider =
    FutureProvider.family<List<StudentGrade>, String>((ref, classroomId) async {
  return ref.watch(classroomRepositoryProvider).fetchGrades(classroomId);
});
