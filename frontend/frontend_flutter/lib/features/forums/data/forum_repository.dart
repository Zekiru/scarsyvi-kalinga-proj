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
  // FORUMS READS & CREATION
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

  /// Fetches or auto-resolves the forum linked to a specific `LessonPlan`
  /// via `GET /api/v1/forums/forums/by-lesson-plan/?lesson_plan={id}`[cite: 3].
  Future<Forum> fetchForumByLessonPlan(int lessonPlanServerId) async {
    final response = await _apiClient.get(
      ApiEndpoints.forumByLessonPlan,
      queryParams: {'lesson_plan': lessonPlanServerId},
    );
    return Forum.fromJson(response as Map<String, dynamic>);
  }

  Future<Forum> createForum({
    required String title,
    String description = '',
    String? lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final deps = <String>[];
    final isLpTemp = lessonPlanId != null &&
        lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    if (isLpTemp) deps.add(lessonPlanId);

    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      if (lessonPlanId != null && lessonPlanId.isNotEmpty)
        'lesson_plan': isLpTemp ? lessonPlanId : int.parse(lessonPlanId),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Lesson plan offline draft', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.forums, body: payload);
      final created = Forum.fromJson(response as Map<String, dynamic>);
      await _upsertForumCache(created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('frm');
      final draft = Forum(
        id: tempId,
        title: title.trim(),
        description: description.trim(),
        lessonPlanId: lessonPlanId,
        lessonPlanTitle: lessonPlanTitle,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'forum',
        method: 'POST',
        endpoint: ApiEndpoints.forums,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'id',
        dependsOnTempIds: deps,
      );
      await _upsertForumCache(draft);
      return draft;
    }
  }

  Future<void> _upsertForumCache(Forum forum) async {
    final list = [...getCachedForums()];
    final idx = list.indexWhere((f) => f.id == forum.id);
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

      // Also fetch posts if not nested in detail response
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
        primaryKeyField: 'id',
        dependsOnTempIds: isForumTemp ? [forumId] : const [],
      );
      await _saveThreadDetailCache(draft);
      return draft;
    }
  }

  // ==========================================
  // POSTS (REPLIES)
  // ==========================================

  Future<ForumPost> createPost({
    required String threadId,
    required String content,
    String? parentPostId,
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
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'forum_post',
        method: 'POST',
        endpoint: ApiEndpoints.posts,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'id',
        dependsOnTempIds: deps,
      );
      await _appendPostToThread(threadId, draft);
      return draft;
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

  // ==========================================
  // MODERATION ACTIONS (`CHECKER` & `ADMIN`)
  // ==========================================

  /// `POST /api/v1/forums/forums/{id}/toggle-lock/`[cite: 3]
  Future<Forum> toggleForumLock(int forumServerId) async {
    final response =
        await _apiClient.post(ApiEndpoints.forumToggleLock(forumServerId));
    final updated = Forum.fromJson(response as Map<String, dynamic>);
    await _upsertForumCache(updated);
    return updated;
  }

  /// `POST /api/v1/forums/threads/{id}/moderate/`[cite: 3]
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

  /// `POST /api/v1/forums/posts/{id}/toggle-hide/`[cite: 3]
  Future<ForumPost> toggleHidePost({
    required String threadId,
    required int postServerId,
  }) async {
    final response =
        await _apiClient.post(ApiEndpoints.postToggleHide(postServerId));
    final updated = ForumPost.fromJson(response as Map<String, dynamic>);

    final existing = getCachedThreadDetail(threadId);
    if (existing != null) {
      final posts = existing.posts
          .map((p) => p.id == updated.id ? updated : p)
          .toList();
      await _saveThreadDetailCache(existing.copyWith(posts: posts));
    }
    return updated;
  }
}
