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
  String _currentSearch = '';

  @override
  Future<List<Classroom>> build() async {
    final repo = ref.watch(classroomRepositoryProvider);
    final cached = repo.getCachedClassrooms();

    if (cached.isNotEmpty) {
      Future.microtask(() => refresh(search: _currentSearch));
      return cached;
    }
    return repo.fetchClassrooms(search: _currentSearch);
  }

  Future<void> refresh({String? search}) async {
    if (search != null) _currentSearch = search;
    final repo = ref.read(classroomRepositoryProvider);
    try {
      final fresh = await repo.fetchClassrooms(search: _currentSearch);
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
    List<String> gradeLevelNames = const [],
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
      gradeLevelNames: gradeLevelNames,
      lessonPlanId: lessonPlanId,
      lessonPlanTitle: lessonPlanTitle,
      adviserId: user?.id,
      adviserName: user?.fullName.isNotEmpty == true
          ? user!.fullName
          : (user?.username ?? ''),
    );

    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<Classroom> updateClassroom({
    required String classroomId,
    required String name,
    String schoolName = '',
    String section = '',
    String schoolYear = '',
    bool isActive = true,
    List<int> gradeLevelIds = const [],
    List<String> gradeLevelNames = const [],
    String? lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final repo = ref.read(classroomRepositoryProvider);
    final updated = await repo.updateClassroom(
      classroomId: classroomId,
      name: name,
      schoolName: schoolName,
      section: section,
      schoolYear: schoolYear,
      isActive: isActive,
      gradeLevelIds: gradeLevelIds,
      gradeLevelNames: gradeLevelNames,
      lessonPlanId: lessonPlanId,
      lessonPlanTitle: lessonPlanTitle,
    );

    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData(
      current.map((c) => c.id == classroomId ? updated : c).toList(),
    );
    ref.invalidate(classroomDetailProvider(classroomId));
    return updated;
  }

  Future<void> deleteClassroom(String classroomId) async {
    final repo = ref.read(classroomRepositoryProvider);
    await repo.deleteClassroom(classroomId);
    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData(current.where((c) => c.id != classroomId).toList());
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
    this.search = '',
  });

  final String classroomId;
  final String ordering;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is RosterQuery &&
      other.classroomId == classroomId &&
      other.ordering == ordering &&
      other.search == search;

  @override
  int get hashCode => Object.hash(classroomId, ordering, search);
}

final classroomRosterProvider =
    FutureProvider.family<List<Student>, RosterQuery>((ref, query) async {
  return ref.watch(classroomRepositoryProvider).fetchClassroomStudents(
        query.classroomId,
        ordering: query.ordering,
        search: query.search,
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

class GradesQuery {
  const GradesQuery({
    required this.classroomId,
    this.lessonPlanId,
    this.enrolledStudentIds = const {},
  });

  final String classroomId;
  final String? lessonPlanId;
  final Set<String> enrolledStudentIds;

  @override
  bool operator ==(Object other) =>
      other is GradesQuery &&
      other.classroomId == classroomId &&
      other.lessonPlanId == lessonPlanId &&
      other.enrolledStudentIds.length == enrolledStudentIds.length &&
      other.enrolledStudentIds.containsAll(enrolledStudentIds);

  @override
  int get hashCode => Object.hash(
        classroomId,
        lessonPlanId,
        Object.hashAllUnordered(enrolledStudentIds),
      );
}

final classroomGradesProvider =
    FutureProvider.family<List<StudentGrade>, GradesQuery>((ref, query) async {
  return ref.watch(classroomRepositoryProvider).fetchGrades(
        query.classroomId,
        lessonPlanId: query.lessonPlanId,
        enrolledStudentIds: query.enrolledStudentIds,
      );
});
