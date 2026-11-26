import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/id_mapping_store.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
import '../../curriculum/providers/curriculum_provider.dart';
import '../data/forum_models.dart';
import '../data/forum_repository.dart';

final forumsProvider =
    AsyncNotifierProvider<ForumsNotifier, List<Forum>>(
  ForumsNotifier.new,
);

class ForumsNotifier extends AsyncNotifier<List<Forum>> {
  String _search = '';

  @override
  Future<List<Forum>> build() async {
    final repo = ref.watch(forumRepositoryProvider);
    final cached = repo.getCachedForums();

    if (cached.isNotEmpty) {
      Future.microtask(() => refresh());
      return cached;
    }
    return repo.fetchForums(search: _search);
  }

  Future<void> refresh({String? search}) async {
    if (search != null) _search = search;
    final repo = ref.read(forumRepositoryProvider);
    try {
      final fresh = await repo.fetchForums(search: _search);
      state = AsyncData(fresh);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  /// Idempotently initializes or fetches a LessonPlanForum via
  /// `POST /api/v1/forums/forums/by-lesson-plan/`.
  Future<Forum> openOrCreateForumForLessonPlan({
    required String lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final repo = ref.read(forumRepositoryProvider);
    final forum = await repo.getOrCreateForumForLessonPlan(
      lessonPlanId: lessonPlanId,
      lessonPlanTitle: lessonPlanTitle,
    );
    ref.read(syncStatusProvider.notifier).refreshCounts();

    final current = state.value ?? const [];
    final idx = current.indexWhere(
      (f) =>
          f.id == forum.id ||
          (forum.lessonPlanId != null &&
              forum.lessonPlanId!.isNotEmpty &&
              f.lessonPlanId == forum.lessonPlanId),
    );
    if (idx >= 0) {
      final updated = [...current];
      updated[idx] = forum;
      state = AsyncData(updated);
    } else {
      state = AsyncData([forum, ...current]);
    }
    return forum;
  }

  Future<void> deleteForum(String forumId) async {
    final repo = ref.read(forumRepositoryProvider);
    await repo.deleteForum(forumId);
    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData(current.where((f) => f.id != forumId).toList());
  }
}

/// Resolves all forum IDs the current user has participated in (created a
/// thread or posted a reply), backed by Hive cache + server queries.
final participatedForumIdsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(syncCompletedTickProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  return ref.watch(forumRepositoryProvider).fetchParticipatedForumIds(user.id);
});

/// Evaluates whether the current user is a Forum Moderator for `lessonPlanId`:
/// - `ADMIN` or `CHECKER` (via `currentUser.canModerate`), OR
/// - An assigned author (`LpAuthor`) of the linked `LessonPlan`.
final forumModeratorProvider =
    Provider.family<bool, String?>((ref, lessonPlanId) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return false;
  if (currentUser.canModerate) return true;

  if (lessonPlanId == null || lessonPlanId.isEmpty) return false;
  final planAsync = ref.watch(lessonPlanDetailProvider(lessonPlanId));
  final plan = planAsync.value;
  if (plan != null) {
    return plan.authorIds.contains(currentUser.id);
  }

  final plansList = ref.watch(lessonPlansProvider).value ?? const [];
  final matchingPlan =
      plansList.where((p) => p.id == lessonPlanId).firstOrNull;
  if (matchingPlan != null) {
    return matchingPlan.authorIds.contains(currentUser.id);
  }
  return false;
});

final forumThreadsProvider =
    FutureProvider.family<List<ForumThread>, String>((ref, forumId) async {
  ref.watch(syncCompletedTickProvider);
  final resolvedId = ref.read(idMappingStoreProvider).resolveId(forumId);
  return ref.watch(forumRepositoryProvider).fetchThreads(resolvedId);
});

final threadDetailProvider =
    FutureProvider.family<ForumThread, String>((ref, threadId) async {
  ref.watch(syncCompletedTickProvider);
  final resolvedId = ref.read(idMappingStoreProvider).resolveId(threadId);
  return ref.watch(forumRepositoryProvider).fetchThreadDetail(resolvedId);
});

final forumReplyHelperProvider = Provider((ref) {
  return ({
    required String threadId,
    required String content,
    String? parentPostId,
    String parentAuthorUsername = '',
  }) async {
    final user = ref.read(currentUserProvider);
    final resolvedThreadId =
        ref.read(idMappingStoreProvider).resolveId(threadId);
    final post = await ref.read(forumRepositoryProvider).createPost(
          threadId: resolvedThreadId,
          content: content,
          parentPostId: parentPostId,
          parentAuthorUsername: parentAuthorUsername,
          authorId: user?.id,
          authorName: user?.username ?? '',
          authorRole: user?.role.apiValue ?? '',
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(threadDetailProvider(threadId));
    ref.invalidate(threadDetailProvider(resolvedThreadId));
    ref.invalidate(participatedForumIdsProvider);
    return post;
  };
});
