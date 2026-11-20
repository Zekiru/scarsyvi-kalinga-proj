import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../../accounts/providers/auth_provider.dart';
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

  Future<Forum> createForum({
    required String title,
    String description = '',
    String? lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final repo = ref.read(forumRepositoryProvider);
    final created = await repo.createForum(
      title: title,
      description: description,
      lessonPlanId: lessonPlanId,
      lessonPlanTitle: lessonPlanTitle,
    );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    final current = state.value ?? const [];
    state = AsyncData([created, ...current]);
    return created;
  }
}

final forumThreadsProvider =
    FutureProvider.family<List<ForumThread>, String>((ref, forumId) async {
  return ref.watch(forumRepositoryProvider).fetchThreads(forumId);
});

final threadDetailProvider =
    FutureProvider.family<ForumThread, String>((ref, threadId) async {
  return ref.watch(forumRepositoryProvider).fetchThreadDetail(threadId);
});

final forumReplyHelperProvider = Provider((ref) {
  return ({
    required String threadId,
    required String content,
    String? parentPostId,
  }) async {
    final user = ref.read(currentUserProvider);
    final post = await ref.read(forumRepositoryProvider).createPost(
          threadId: threadId,
          content: content,
          parentPostId: parentPostId,
          authorId: user?.id,
          authorName: user?.username ?? '',
          authorRole: user?.role.apiValue ?? '',
        );
    ref.read(syncStatusProvider.notifier).refreshCounts();
    ref.invalidate(threadDetailProvider(threadId));
    return post;
  };
});
