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
    String learnerContext = '',
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
      learnerContext: learnerContext,
      isPublic: isPublic,
      authorId: user?.id,
      authorName: user?.username ?? '',
    );

    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData([created, ...current]);
    return created;
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
