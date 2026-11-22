import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/sync/id_mapping_store.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'forum_models.dart';

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepository(
    apiClient: ref.watch(apiClientProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
    cacheBox: HiveBoxes.forums,
  );
});

class ForumRepository {
  ForumRepository({
    required this._apiClient,
    required this._syncQueue,
    required this._cacheBox,
  });

  final ApiClient _apiClient;
  final SyncQueueService _syncQueue;
  final Box<String> _cacheBox;

  static const String _forumsKey = 'forums_list';
  static String _forumThreadsKey(String forumId) => 'forum_threads_$forumId';
  static String _threadDetailKey(String threadId) => 'thread_detail_$threadId';

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic> && response['results'] is List) {
      return response['results'] as List<dynamic>;
    }
    return const [];
  }

  List<T> _parseItems<T>(
    List<dynamic> rawList,
    T Function(Map<String, dynamic>) parser,
  ) {
    final result = <T>[];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        result.add(parser(item));
      }
    }
    return result;
  }

  // ==========================================
  // FORUMS READS, INITIALIZATION & DELETION
  // ==========================================

  Future<List<Forum>> fetchForums({String? search}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.forums,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final serverForums = _parseItems(_extractList(response), Forum.fromJson);

      final unsyncedLocal =
          getCachedForums().where((f) => f.isLocalDraft).toList();
      final merged = [...unsyncedLocal, ...serverForums];

      await _cacheBox.put(_forumsKey, Forum.encodeList(merged));
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedForums();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<Forum> getCachedForums() {
    final raw = _cacheBox.get(_forumsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return Forum.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  static String _participatedForumsKey(int userId) =>
      'participated_forums_$userId';

  Set<String> getCachedParticipatedForumIds(int userId) {
    final raw = _cacheBox.get(_participatedForumsKey(userId));
    if (raw == null || raw.isEmpty) return const {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Queries `GET /api/v1/forums/threads/?author={userId}` and
  /// `GET /api/v1/forums/posts/?author={userId}`[cite: 1, 6] to find every forum
  /// the user has created a thread or posted a reply in, caching the result
  /// in Hive for offline startup.
  Future<Set<String>> fetchParticipatedForumIds(int userId) async {
    final forumIds = <String>{...getCachedParticipatedForumIds(userId)};

    // Also include any local offline drafts authored by this user
    for (final forum in getCachedForums()) {
      for (final thread in getCachedThreads(forum.id)) {
        if (thread.authorId == userId) {
          forumIds.add(forum.id);
        }
        final detail = getCachedThreadDetail(thread.id);
        for (final post in (detail?.posts ?? thread.posts)) {
          if (post.authorId == userId) {
            forumIds.add(forum.id);
          }
        }
      }
    }

    try {
      // 1. Threads authored by user -> directly exposes `forum` ID[cite: 4]
      final threadsResp = await _apiClient.get(
        ApiEndpoints.threads,
        queryParams: {'author': userId},
      );
      final userThreads =
          _parseItems(_extractList(threadsResp), ForumThread.fromJson);
      final threadIdToForumId = <String, String>{};
      for (final t in userThreads) {
        if (t.forumId.isNotEmpty) {
          forumIds.add(t.forumId);
          threadIdToForumId[t.id] = t.forumId;
        }
      }

      // 2. Posts authored by user -> resolve `thread` -> `forum` ID[cite: 4]
      final postsResp = await _apiClient.get(
        ApiEndpoints.posts,
        queryParams: {'author': userId},
      );
      final userPosts =
          _parseItems(_extractList(postsResp), ForumPost.fromJson);
      final unresolvedThreadIds = <String>{};
      for (final p in userPosts) {
        final knownForum = threadIdToForumId[p.threadId];
        if (knownForum != null && knownForum.isNotEmpty) {
          forumIds.add(knownForum);
        } else if (p.threadId.isNotEmpty) {
          unresolvedThreadIds.add(p.threadId);
        }
      }

      for (final thrId in unresolvedThreadIds) {
        final cachedDetail = getCachedThreadDetail(thrId);
        if (cachedDetail != null && cachedDetail.forumId.isNotEmpty) {
          forumIds.add(cachedDetail.forumId);
          continue;
        }
        final sId = int.tryParse(thrId);
        if (sId != null) {
          try {
            final thrResp =
                await _apiClient.get(ApiEndpoints.threadDetail(sId));
            final thr =
                ForumThread.fromJson(thrResp as Map<String, dynamic>);
            if (thr.forumId.isNotEmpty) {
              forumIds.add(thr.forumId);
            }
          } catch (_) {}
        }
      }

      await _cacheBox.put(
        _participatedForumsKey(userId),
        jsonEncode(forumIds.toList()),
      );
      return forumIds;
    } on ApiException {
      return forumIds;
    }
  }

  /// Idempotently initializes or fetches the `LessonPlanForum` for a `LessonPlan`
  /// via `POST /api/v1/forums/forums/by-lesson-plan/` with `{"lesson_plan_id": id}`[cite: 6, 9, 11].
  Future<Forum> getOrCreateForumForLessonPlan({
    required String lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final isLpTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final payload = <String, dynamic>{
      'lesson_plan_id': isLpTemp ? lessonPlanId : int.parse(lessonPlanId),
    };

    try {
      if (isLpTemp) {
        throw ApiException(message: 'Lesson plan offline draft', isOffline: true);
      }
      final response = await _apiClient.post(
        ApiEndpoints.forumByLessonPlan,
        body: payload,
      );
      final forum = Forum.fromJson(response as Map<String, dynamic>);
      await _upsertForumCache(forum);
      return forum;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final existingCached = getCachedForums()
          .where((f) => f.lessonPlanId == lessonPlanId)
          .firstOrNull;
      if (existingCached != null) return existingCached;

      final tempId = IdMappingStore.generateTempId('frm');
      final draft = Forum(
        id: tempId,
        title: lessonPlanTitle,
        lessonPlanId: lessonPlanId,
        lessonPlanTitle: lessonPlanTitle,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'forum',
        method: 'POST',
        endpoint: ApiEndpoints.forumByLessonPlan,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'forum_id',
        dependsOnTempIds: isLpTemp ? [lessonPlanId] : const [],
      );
      await _upsertForumCache(draft);
      return draft;
    }
  }

  Future<void> deleteForum(String forumId) async {
    final serverId = int.tryParse(forumId);
    final updated = getCachedForums().where((f) => f.id != forumId).toList();
    await _cacheBox.put(_forumsKey, Forum.encodeList(updated));
    await _cacheBox.delete(_forumThreadsKey(forumId));

    if (serverId == null) return;

    try {
      await _apiClient.delete('${ApiEndpoints.forums}$serverId/');
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      await _syncQueue.enqueue(
        entityType: 'forum',
        method: 'DELETE',
        endpoint: '${ApiEndpoints.forums}$serverId/',
        payload: const {},
      );
    }
  }

  Future<void> _upsertForumCache(Forum forum) async {
    final list = [...getCachedForums()];
    final idx = list.indexWhere(
      (f) =>
          f.id == forum.id ||
          (forum.lessonPlanId != null &&
              forum.lessonPlanId!.isNotEmpty &&
              f.lessonPlanId == forum.lessonPlanId),
    );
    if (idx >= 0) {
      list[idx] = forum;
    } else {
      list.insert(0, forum);
    }
    await _cacheBox.put(_forumsKey, Forum.encodeList(list));
  }

  // ==========================================
  // THREADS READS & MUTATIONS
  // ==========================================

  Future<List<ForumThread>> fetchThreads(String forumId) async {
    final serverId = int.tryParse(forumId);
    if (serverId == null) {
      return getCachedThreads(forumId);
    }

    try {
      final response = await _apiClient.get(
        ApiEndpoints.threads,
        queryParams: {'forum': serverId},
      );
      final serverThreads =
          _parseItems(_extractList(response), ForumThread.fromJson);

      final localDrafts =
          getCachedThreads(forumId).where((t) => t.isLocalDraft).toList();
      final merged = [...localDrafts, ...serverThreads];

      await _cacheBox.put(
        _forumThreadsKey(forumId),
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedThreads(forumId);
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<ForumThread> getCachedThreads(String forumId) {
    final raw = _cacheBox.get(_forumThreadsKey(forumId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      return _parseItems(
        jsonDecode(raw) as List<dynamic>,
        ForumThread.fromJson,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<ForumThread> fetchThreadDetail(String threadId) async {
    final serverId = int.tryParse(threadId);
    if (serverId == null) {
      final cached = getCachedThreadDetail(threadId);
      if (cached != null) return cached;
      throw ApiException(message: 'Local draft thread not found.');
    }

    try {
      final response =
          await _apiClient.get(ApiEndpoints.threadDetail(serverId));
      var thread = ForumThread.fromJson(response as Map<String, dynamic>);

      if (thread.posts.isEmpty) {
        final postsResp = await _apiClient.get(
          ApiEndpoints.posts,
          queryParams: {'thread': serverId},
        );
        final posts = _parseItems(_extractList(postsResp), ForumPost.fromJson);
        thread = thread.copyWith(posts: posts);
      }

      // Preserve any offline-queued replies for this thread
      final existing = getCachedThreadDetail(threadId);
      if (existing != null) {
        final pendingPosts =
            existing.posts.where((p) => p.isPendingSync).toList();
        if (pendingPosts.isNotEmpty) {
          thread = thread.copyWith(posts: [...thread.posts, ...pendingPosts]);
        }
      }

      await _saveThreadDetailCache(thread);
      return thread;
    } on ApiException catch (e) {
      final cached = getCachedThreadDetail(threadId);
      if (e.isOffline && cached != null) return cached;
      if (cached != null) return cached;
      rethrow;
    }
  }

  ForumThread? getCachedThreadDetail(String threadId) {
    final raw = _cacheBox.get(_threadDetailKey(threadId));
    if (raw != null && raw.isNotEmpty) {
      try {
        return ForumThread.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _saveThreadDetailCache(ForumThread thread) async {
    await _cacheBox.put(
      _threadDetailKey(thread.id),
      jsonEncode(thread.toJson()),
    );
    final list = [...getCachedThreads(thread.forumId)];
    final idx = list.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      list[idx] = thread;
    } else {
      list.insert(0, thread);
    }
    await _cacheBox.put(
      _forumThreadsKey(thread.forumId),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<ForumThread> createThread({
    required String forumId,
    required String title,
    required String body,
    int? authorId,
    String authorName = '',
  }) async {
    final isForumTemp = forumId.startsWith(IdMappingStore.tempPrefix);
    final payload = <String, dynamic>{
      'forum': isForumTemp ? forumId : int.parse(forumId),
      'title': title.trim(),
      'body': body.trim(),
    };

    try {
      if (isForumTemp) {
        throw ApiException(message: 'Forum offline draft', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.threads, body: payload);
      final created = ForumThread.fromJson(response as Map<String, dynamic>);
      await _saveThreadDetailCache(created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('thr');
      final draft = ForumThread(
        id: tempId,
        forumId: forumId,
        title: title.trim(),
        body: body.trim(),
        authorId: authorId,
        authorName: authorName,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'forum_thread',
        method: 'POST',
        endpoint: ApiEndpoints.threads,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'thread_id',
        dependsOnTempIds: isForumTemp ? [forumId] : const [],
      );
      await _saveThreadDetailCache(draft);
      return draft;
    }
  }

  Future<ForumThread> updateThread({
    required ForumThread thread,
    required String title,
    required String body,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
    };

    final serverId = thread.serverId;
    if (serverId == null) {
      final updated = thread.copyWith(
        title: title.trim(),
        body: body.trim(),
        isPendingSync: true,
      );
      await _saveThreadDetailCache(updated);
      return updated;
    }

    try {
      final response = await _apiClient.patch(
        ApiEndpoints.threadDetail(serverId),
        body: payload,
      );
      final updated = ForumThread.fromJson(response as Map<String, dynamic>);
      await _saveThreadDetailCache(updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      final updated = thread.copyWith(
        title: title.trim(),
        body: body.trim(),
        isPendingSync: true,
      );
      await _syncQueue.enqueue(
        entityType: 'forum_thread',
        method: 'PATCH',
        endpoint: ApiEndpoints.threadDetail(serverId),
        payload: payload,
      );
      await _saveThreadDetailCache(updated);
      return updated;
    }
  }

  Future<void> deleteThread(ForumThread thread) async {
    await _cacheBox.delete(_threadDetailKey(thread.id));
    final list = getCachedThreads(thread.forumId)
        .where((t) => t.id != thread.id)
        .toList();
    await _cacheBox.put(
      _forumThreadsKey(thread.forumId),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );

    final serverId = thread.serverId;
    if (serverId == null) return;

    try {
      await _apiClient.delete(ApiEndpoints.threadDetail(serverId));
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      await _syncQueue.enqueue(
        entityType: 'forum_thread',
        method: 'DELETE',
        endpoint: ApiEndpoints.threadDetail(serverId),
        payload: const {},
      );
    }
  }

  // ==========================================
  // POSTS (TOP-LEVEL & NESTED REPLIES)
  // ==========================================

  Future<ForumPost> createPost({
    required String threadId,
    required String content,
    String? parentPostId,
    String parentAuthorUsername = '',
    int? authorId,
    String authorName = '',
    String authorRole = '',
  }) async {
    final deps = <String>[];
    final isThreadTemp = threadId.startsWith(IdMappingStore.tempPrefix);
    if (isThreadTemp) deps.add(threadId);

    final isParentPostTemp = parentPostId != null &&
        parentPostId.startsWith(IdMappingStore.tempPrefix);
    if (isParentPostTemp) deps.add(parentPostId);

    final payload = <String, dynamic>{
      'thread': isThreadTemp ? threadId : int.parse(threadId),
      'content': content.trim(),
      if (parentPostId != null && parentPostId.isNotEmpty)
        'parent_post':
            isParentPostTemp ? parentPostId : int.parse(parentPostId),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.posts, body: payload);
      final created = ForumPost.fromJson(response as Map<String, dynamic>);
      await _appendPostToThread(threadId, created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('pst');
      final draft = ForumPost(
        id: tempId,
        threadId: threadId,
        content: content.trim(),
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        parentPostId: parentPostId,
        parentAuthorUsername: parentAuthorUsername,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'forum_post',
        method: 'POST',
        endpoint: ApiEndpoints.posts,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'post_id',
        dependsOnTempIds: deps,
      );
      await _appendPostToThread(threadId, draft);
      return draft;
    }
  }

  Future<ForumPost> updatePost({
    required String threadId,
    required ForumPost post,
    required String content,
  }) async {
    final payload = <String, dynamic>{'content': content.trim()};
    final serverId = post.serverId;

    if (serverId == null) {
      final updated = post.copyWith(
        content: content.trim(),
        isPendingSync: true,
      );
      await _replacePostInThread(threadId, updated);
      return updated;
    }

    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.posts}$serverId/',
        body: payload,
      );
      final updated = ForumPost.fromJson(response as Map<String, dynamic>);
      await _replacePostInThread(threadId, updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      final updated = post.copyWith(
        content: content.trim(),
        isPendingSync: true,
      );
      await _syncQueue.enqueue(
        entityType: 'forum_post',
        method: 'PATCH',
        endpoint: '${ApiEndpoints.posts}$serverId/',
        payload: payload,
      );
      await _replacePostInThread(threadId, updated);
      return updated;
    }
  }

  Future<void> deletePost({
    required String threadId,
    required ForumPost post,
  }) async {
    final existing = getCachedThreadDetail(threadId);
    if (existing != null) {
      final filtered = existing.posts.where((p) => p.id != post.id).toList();
      await _saveThreadDetailCache(
        existing.copyWith(
          posts: filtered,
          postCount: filtered.length,
        ),
      );
    }

    final serverId = post.serverId;
    if (serverId == null) return;

    try {
      await _apiClient.delete('${ApiEndpoints.posts}$serverId/');
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      await _syncQueue.enqueue(
        entityType: 'forum_post',
        method: 'DELETE',
        endpoint: '${ApiEndpoints.posts}$serverId/',
        payload: const {},
      );
    }
  }

  Future<void> _appendPostToThread(String threadId, ForumPost post) async {
    final existing = getCachedThreadDetail(threadId);
    if (existing == null) return;
    final updated = existing.copyWith(
      posts: [...existing.posts, post],
      postCount: existing.postCount + 1,
    );
    await _saveThreadDetailCache(updated);
  }

  Future<void> _replacePostInThread(String threadId, ForumPost updatedPost) async {
    final existing = getCachedThreadDetail(threadId);
    if (existing == null) return;
    final posts = existing.posts
        .map((p) => p.id == updatedPost.id ? updatedPost : p)
        .toList();
    await _saveThreadDetailCache(existing.copyWith(posts: posts));
  }

  // ==========================================
  // MODERATION ACTIONS (`ADMIN`, `CHECKER`, & `LP AUTHOR`)
  // ==========================================

  /// `POST /api/v1/forums/forums/{id}/toggle-lock/`[cite: 6, 11]
  Future<Forum> toggleForumLock(int forumServerId) async {
    final response =
        await _apiClient.post(ApiEndpoints.forumToggleLock(forumServerId));
    final updated = Forum.fromJson(response as Map<String, dynamic>);
    await _upsertForumCache(updated);
    return updated;
  }

  /// `POST /api/v1/forums/threads/{id}/moderate/`[cite: 6, 11]
  Future<ForumThread> moderateThread({
    required int threadServerId,
    bool? isPinned,
    bool? isLocked,
    bool? isHidden,
  }) async {
    final payload = <String, dynamic>{
      'is_pinned': ?isPinned,
      'is_locked': ?isLocked,
      'is_hidden': ?isHidden,
    };

    final response = await _apiClient.post(
      ApiEndpoints.threadModerate(threadServerId),
      body: payload,
    );
    final updated = ForumThread.fromJson(response as Map<String, dynamic>);
    await _saveThreadDetailCache(updated);
    return updated;
  }

  /// `POST /api/v1/forums/posts/{id}/toggle-hide/`[cite: 6, 11]
  Future<ForumPost> toggleHidePost({
    required String threadId,
    required int postServerId,
  }) async {
    final response =
        await _apiClient.post(ApiEndpoints.postToggleHide(postServerId));
    final updated = ForumPost.fromJson(response as Map<String, dynamic>);
    await _replacePostInThread(threadId, updated);
    return updated;
  }
}
