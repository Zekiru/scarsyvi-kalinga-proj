import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/data/account_model.dart';
import '../../features/accounts/providers/auth_provider.dart';
import '../../features/classrooms/data/classroom_repository.dart';
import '../../features/classrooms/providers/classroom_provider.dart';
import '../../features/curriculum/data/curriculum_repository.dart';
import '../../features/curriculum/providers/curriculum_provider.dart';
import '../../features/forums/data/forum_repository.dart';
import '../../features/forums/providers/forum_provider.dart';

final offlinePrefetchServiceProvider = Provider<OfflinePrefetchService>((ref) {
  return OfflinePrefetchService(ref);
});

class OfflinePrefetchService {
  OfflinePrefetchService(this._ref);

  final Ref _ref;
  bool _isRunning = false;

  Future<void> prefetchOwnedData() async {
    if (_isRunning) return;
    final Account? user = _ref.read(currentUserProvider);
    if (user == null) return;

    _isRunning = true;
    try {
      final curriculumRepo = _ref.read(curriculumRepositoryProvider);
      final classroomRepo = _ref.read(classroomRepositoryProvider);
      final forumRepo = _ref.read(forumRepositoryProvider);

      // 1. Fetch top-level lists + grade levels + participated forum IDs
      final results = await Future.wait([
        curriculumRepo.fetchGradeLevels(),
        curriculumRepo.fetchLessonPlans(),
        classroomRepo.fetchClassrooms(),
        forumRepo.fetchForums(),
        forumRepo.fetchParticipatedForumIds(user.id),
      ]);

      // Refresh UI notifiers with the updated top-level lists
      _ref.invalidate(lessonPlansProvider);
      _ref.invalidate(classroomsProvider);
      _ref.invalidate(forumsProvider);
      _ref.invalidate(participatedForumIdsProvider);

      final allPlans = results[1] as List;
      final allClassrooms = results[2] as List;
      final allForums = results[3] as List;
      final participatedIds = results[4] as Set<String>;

      // 2. Hydrate full details for OWNED & CO-OWNED Lesson Plans
      final ownedPlans = allPlans.where((p) {
        return !p.isLocalDraft &&
            (p.isOwnedBy(user.id, currentUsername: user.username) ||
                p.isContributedBy(user.id, currentUsername: user.username));
      }).toList();

      for (final plan in ownedPlans) {
        try {
          await curriculumRepo.fetchLessonPlanDetail(plan.id);
        } catch (_) {}
      }

      // 3. Hydrate full details (roster, attendance, grades) for OWNED Classrooms
      final ownedClassrooms = allClassrooms.where((c) {
        return !c.isLocalDraft &&
            c.adviserId != null &&
            c.adviserId == user.id;
      }).toList();

      for (final cls in ownedClassrooms) {
        try {
          final detailed = await classroomRepo.fetchClassroomDetail(cls.id);
          final enrolledIds = detailed.students.map((s) => s.id).toSet();
          await Future.wait([
            classroomRepo.fetchAttendanceSessions(cls.id),
            classroomRepo.fetchGrades(
              cls.id,
              lessonPlanId: detailed.lessonPlanId,
              enrolledStudentIds: enrolledIds,
            ),
          ]);
        } catch (_) {}
      }

      // 4. Hydrate threads & posts for OWNED or PARTICIPATED Forums
      final ownedPlanIds = ownedPlans.map((p) => p.id).toSet();
      final relevantForums = allForums.where((f) {
        if (f.isLocalDraft) return false;
        final isOwnedForum =
            f.lessonPlanId != null && ownedPlanIds.contains(f.lessonPlanId);
        return isOwnedForum || participatedIds.contains(f.id);
      }).toList();

      for (final forum in relevantForums) {
        try {
          final threads = await forumRepo.fetchThreads(forum.id);
          for (final thread in threads) {
            if (!thread.isLocalDraft) {
              await forumRepo.fetchThreadDetail(thread.id);
            }
          }
        } catch (_) {}
      }
    } finally {
      _isRunning = false;
    }
  }
}
