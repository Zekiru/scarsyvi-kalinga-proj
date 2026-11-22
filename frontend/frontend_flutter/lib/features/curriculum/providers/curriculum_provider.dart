import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/curriculum_models.dart';
import '../data/curriculum_repository.dart';

final gradeLevelsProvider = FutureProvider<List<GradeLevel>>((ref) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.fetchGradeLevels();
});

final lessonPlansProvider =
    AsyncNotifierProvider<LessonPlansNotifier, List<LessonPlan>>(
  LessonPlansNotifier.new,
);

class LessonPlansNotifier extends AsyncNotifier<List<LessonPlan>> {
  String _currentSearch = '';

  @override
  Future<List<LessonPlan>> build() async {
    final repo = ref.watch(curriculumRepositoryProvider);
    final cached = repo.getCachedLessonPlans();
    if (cached.isNotEmpty) {
      Future.microtask(() => refresh(search: _currentSearch));
      return cached;
    }
    return repo.fetchLessonPlans();
  }

  Future<void> refresh({String? search}) async {
    if (search != null) _currentSearch = search;
    final repo = ref.read(curriculumRepositoryProvider);
    try {
      final fresh = await repo.fetchLessonPlans(search: _currentSearch);
      state = AsyncData(fresh);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  LessonPlan _attachCurrentUserIfMissing(LessonPlan plan, dynamic currentUser) {
    if (currentUser == null) return plan;
    final hasResolvedAuthor = plan.authorEntries.any(
      (e) => e.username.trim().isNotEmpty || e.fullName.trim().isNotEmpty,
    );
    if (hasResolvedAuthor) return plan;

    return plan.copyWith(
      authorId: plan.authorId ?? currentUser.id,
      authorName: currentUser.username,
      authorIds: plan.authorIds.isEmpty ? [currentUser.id] : plan.authorIds,
      authorEntries: [
        LessonAuthorEntry(
          userId: currentUser.id,
          username: currentUser.username,
          fullName: currentUser.fullName,
          authorRole: 'Primary Author',
        ),
      ],
    );
  }

  Future<LessonPlan> createLessonPlan({
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    String multigradeModel = '',
    String sharedSubTheme = '',
    bool isPublic = true,
  }) async {
    final repo = ref.read(curriculumRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);

    var created = await repo.createLessonPlan(
      title: title,
      subject: subject,
      primaryLanguage: primaryLanguage,
      suggestedDemographic: suggestedDemographic,
      multigradeModel: multigradeModel,
      sharedSubTheme: sharedSubTheme,
      isPublic: isPublic,
      authorId: currentUser?.id,
      authorName: currentUser?.username ?? '',
    );

    created = _attachCurrentUserIfMissing(created, currentUser);
    await repo.saveCachedLessonPlan(created);

    final current = state.value ?? repo.getCachedLessonPlans();
    state = AsyncData([
      created,
      ...current.where((p) => p.id != created.id),
    ]);
    ref.invalidate(lessonPlanDetailProvider(created.id));
    ref.read(syncStatusProvider.notifier).refreshCounts();
    return created;
  }

  Future<LessonPlan> updateLessonPlan({
    required String lessonPlanId,
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    String multigradeModel = '',
    String sharedSubTheme = '',
    String learnerContext = '',
    String reflectionQuestions = '',
    String notesForNextSession = '',
    bool isPublic = true,
  }) async {
    final repo = ref.read(curriculumRepositoryProvider);
    final updated = await repo.updateLessonPlan(
      lessonPlanId: lessonPlanId,
      title: title,
      subject: subject,
      primaryLanguage: primaryLanguage,
      suggestedDemographic: suggestedDemographic,
      multigradeModel: multigradeModel,
      sharedSubTheme: sharedSubTheme,
      learnerContext: learnerContext,
      reflectionQuestions: reflectionQuestions,
      notesForNextSession: notesForNextSession,
      isPublic: isPublic,
    );

    final current = state.value ?? repo.getCachedLessonPlans();
    state = AsyncData(
      current.map((p) => p.id == lessonPlanId ? updated : p).toList(),
    );
    ref.invalidate(lessonPlanDetailProvider(lessonPlanId));
    ref.read(syncStatusProvider.notifier).refreshCounts();
    return updated;
  }

  Future<void> deleteLessonPlan(String lessonPlanId) async {
    final repo = ref.read(curriculumRepositoryProvider);
    await repo.deleteLessonPlan(lessonPlanId);
    final current = state.value ?? repo.getCachedLessonPlans();
    state = AsyncData(current.where((p) => p.id != lessonPlanId).toList());
    ref.read(syncStatusProvider.notifier).refreshCounts();
  }

  Future<LessonPlan> forkLessonPlan(int serverId) async {
    final repo = ref.read(curriculumRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);
    var forked = await repo.forkLessonPlan(serverId);

    forked = _attachCurrentUserIfMissing(forked, currentUser);
    await repo.saveCachedLessonPlan(forked);

    final current = state.value ?? repo.getCachedLessonPlans();
    state = AsyncData([
      forked,
      ...current.where((p) => p.id != forked.id),
    ]);
    ref.invalidate(lessonPlanDetailProvider(forked.id));
    ref.read(syncStatusProvider.notifier).refreshCounts();
    return forked;
  }
}

final lessonPlanDetailProvider =
    FutureProvider.family<LessonPlan, String>((ref, id) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.fetchLessonPlanDetail(id);
});
