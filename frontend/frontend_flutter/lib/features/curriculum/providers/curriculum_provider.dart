import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../data/curriculum_models.dart';
import '../data/curriculum_repository.dart';

final gradeLevelsProvider = FutureProvider<List<GradeLevel>>((ref) async {
  return ref.watch(curriculumRepositoryProvider).fetchGradeLevels();
});

final lessonPlansProvider =
    AsyncNotifierProvider<LessonPlansNotifier, List<LessonPlan>>(
  LessonPlansNotifier.new,
);

class LessonPlansNotifier extends AsyncNotifier<List<LessonPlan>> {
  String _searchQuery = '';

  @override
  Future<List<LessonPlan>> build() async {
    final repo = ref.watch(curriculumRepositoryProvider);
    final cached = repo.getCachedLessonPlans();

    if (cached.isNotEmpty && cached.every((p) => p.title.isNotEmpty)) {
      Future.microtask(() => refresh());
      return cached;
    }
    return repo.fetchLessonPlans(search: _searchQuery);
  }

  Future<void> refresh({String? search}) async {
    if (search != null) _searchQuery = search;
    final repo = ref.read(curriculumRepositoryProvider);
    try {
      final fresh = await repo.fetchLessonPlans(search: _searchQuery);
      state = AsyncData(fresh);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
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
    final user = ref.read(currentUserProvider);
    final repo = ref.read(curriculumRepositoryProvider);

    final created = await repo.createLessonPlan(
      title: title,
      subject: subject,
      primaryLanguage: primaryLanguage,
      suggestedDemographic: suggestedDemographic,
      multigradeModel: multigradeModel,
      sharedSubTheme: sharedSubTheme,
      isPublic: isPublic,
      authorId: user?.id,
      authorName: user?.username ?? '',
    );

    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData([created, ...current]);
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

    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(lessonPlanId));

    final current = state.value ?? const [];
    state = AsyncData([
      for (final item in current)
        if (item.id == lessonPlanId) updated else item,
    ]);
    return updated;
  }

  Future<void> deleteLessonPlan(String lessonPlanId) async {
    final repo = ref.read(curriculumRepositoryProvider);
    await repo.deleteLessonPlan(lessonPlanId);

    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(lessonPlanDetailProvider(lessonPlanId));

    final current = state.value ?? const [];
    state = AsyncData(current.where((p) => p.id != lessonPlanId).toList());
  }

  Future<LessonPlan> forkLessonPlan(int serverId) async {
    final repo = ref.read(curriculumRepositoryProvider);
    final forked = await repo.forkLessonPlan(serverId);
    final current = state.value ?? const [];
    state = AsyncData([forked, ...current]);
    return forked;
  }
}

final lessonPlanDetailProvider =
    FutureProvider.family<LessonPlan, String>((ref, id) async {
  return ref.watch(curriculumRepositoryProvider).fetchLessonPlanDetail(id);
});
