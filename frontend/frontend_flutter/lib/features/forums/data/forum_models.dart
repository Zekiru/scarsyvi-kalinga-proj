import 'dart:convert';

class ForumPost {
  const ForumPost({
    required this.id,
    required this.threadId,
    required this.content,
    this.authorId,
    this.authorName = '',
    this.authorRole = '',
    this.parentPostId,
    this.isHidden = false,
    this.createdAt = '',
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_pst_*`
  final String threadId;
  final String content;
  final int? authorId;
  final String authorName;
  final String authorRole;
  final String? parentPostId;
  final bool isHidden;
  final String createdAt;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final authorObj = json['author_detail'] ?? json['author'];
    int? aId;
    String aName = (json['author_username'] ?? '') as String;
    String aRole = (json['author_role'] ?? '') as String;

    if (authorObj is int) {
      aId = authorObj;
    } else if (authorObj is Map<String, dynamic>) {
      aId = (authorObj['id'] ?? authorObj['user_id']) as int?;
      aName = (authorObj['username'] ?? aName) as String;
      aRole = (authorObj['role'] ?? aRole) as String;
    }

    return ForumPost(
      id: (json['post_id'] ?? json['id'] ?? '').toString(),
      threadId: (json['thread'] ?? '').toString(),
      content: (json['content'] ?? json['body'] ?? '') as String,
      authorId: aId,
      authorName: aName,
      authorRole: aRole,
      parentPostId: json['parent_post']?.toString(),
      isHidden: (json['is_hidden'] ?? false) as bool,
      createdAt: (json['created_at'] ?? '') as String,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thread': threadId,
        'content': content,
        'author': authorId,
        'author_username': authorName,
        'author_role': authorRole,
        'parent_post': parentPostId,
        'is_hidden': isHidden,
        'created_at': createdAt,
        'is_pending_sync': isPendingSync,
      };

  ForumPost copyWith({
    String? id,
    String? threadId,
    String? content,
    int? authorId,
    String? authorName,
    String? authorRole,
    String? parentPostId,
    bool? isHidden,
    String? createdAt,
    bool? isPendingSync,
  }) {
    return ForumPost(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      parentPostId: parentPostId ?? this.parentPostId,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}

class ForumThread {
  const ForumThread({
    required this.id,
    required this.forumId,
    required this.title,
    this.body = '',
    this.authorId,
    this.authorName = '',
    this.isPinned = false,
    this.isLocked = false,
    this.isHidden = false,
    this.postCount = 0,
    this.createdAt = '',
    this.posts = const [],
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_thr_*`
  final String forumId;
  final String title;
  final String body;
  final int? authorId;
  final String authorName;
  final bool isPinned;
  final bool isLocked;
  final bool isHidden;
  final int postCount;
  final String createdAt;
  final List<ForumPost> posts;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final authorObj = json['author_detail'] ?? json['author'];
    int? aId;
    String aName = (json['author_username'] ?? '') as String;

    if (authorObj is int) {
      aId = authorObj;
    } else if (authorObj is Map<String, dynamic>) {
      aId = (authorObj['id'] ?? authorObj['user_id']) as int?;
      aName = (authorObj['username'] ?? aName) as String;
    }

    final parsedPosts = <ForumPost>[];
    final rawPosts = json['posts'];
    if (rawPosts is List) {
      for (final item in rawPosts) {
        if (item is Map<String, dynamic>) {
          parsedPosts.add(ForumPost.fromJson(item));
        }
      }
    }

    return ForumThread(
      id: (json['thread_id'] ?? json['id'] ?? '').toString(),
      forumId: (json['forum'] ?? '').toString(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? json['content'] ?? '') as String,
      authorId: aId,
      authorName: aName,
      isPinned: (json['is_pinned'] ?? false) as bool,
      isLocked: (json['is_locked'] ?? false) as bool,
      isHidden: (json['is_hidden'] ?? false) as bool,
      postCount: (json['post_count'] ?? parsedPosts.length) as int,
      createdAt: (json['created_at'] ?? '') as String,
      posts: parsedPosts,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'forum': forumId,
        'title': title,
        'body': body,
        'author': authorId,
        'author_username': authorName,
        'is_pinned': isPinned,
        'is_locked': isLocked,
        'is_hidden': isHidden,
        'post_count': postCount,
        'created_at': createdAt,
        'posts': posts.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };

  ForumThread copyWith({
    String? id,
    String? forumId,
    String? title,
    String? body,
    int? authorId,
    String? authorName,
    bool? isPinned,
    bool? isLocked,
    bool? isHidden,
    int? postCount,
    String? createdAt,
    List<ForumPost>? posts,
    bool? isPendingSync,
  }) {
    return ForumThread(
      id: id ?? this.id,
      forumId: forumId ?? this.forumId,
      title: title ?? this.title,
      body: body ?? this.body,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      postCount: postCount ?? this.postCount,
      createdAt: createdAt ?? this.createdAt,
      posts: posts ?? this.posts,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}

class Forum {
  const Forum({
    required this.id,
    required this.title,
    this.description = '',
    this.lessonPlanId,
    this.lessonPlanTitle = '',
    this.isLocked = false,
    this.threadCount = 0,
    this.threads = const [],
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_frm_*`
  final String title;
  final String description;
  final String? lessonPlanId;
  final String lessonPlanTitle;
  final bool isLocked;
  final int threadCount;
  final List<ForumThread> threads;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  factory Forum.fromJson(Map<String, dynamic> json) {
    final lpObj = json['lesson_plan_detail'] ?? json['lesson_plan'];
    String? lpId;
    String lpTitle = (json['lesson_plan_title'] ?? '') as String;

    if (lpObj is int || lpObj is String) {
      lpId = lpObj.toString();
    } else if (lpObj is Map<String, dynamic>) {
      lpId = (lpObj['lp_id'] ?? lpObj['id'])?.toString();
      lpTitle = (lpObj['title'] ?? lpTitle) as String;
    }

    final parsedThreads = <ForumThread>[];
    final rawThreads = json['threads'];
    if (rawThreads is List) {
      for (final item in rawThreads) {
        if (item is Map<String, dynamic>) {
          parsedThreads.add(ForumThread.fromJson(item));
        }
      }
    }

    return Forum(
      id: (json['forum_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      lessonPlanId: lpId,
      lessonPlanTitle: lpTitle,
      isLocked: (json['is_locked'] ?? false) as bool,
      threadCount: (json['thread_count'] ?? parsedThreads.length) as int,
      threads: parsedThreads,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'lesson_plan': lessonPlanId,
        'lesson_plan_title': lessonPlanTitle,
        'is_locked': isLocked,
        'thread_count': threadCount,
        'threads': threads.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };

  Forum copyWith({
    String? id,
    String? title,
    String? description,
    String? lessonPlanId,
    String? lessonPlanTitle,
    bool? isLocked,
    int? threadCount,
    List<ForumThread>? threads,
    bool? isPendingSync,
  }) {
    return Forum(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      lessonPlanId: lessonPlanId ?? this.lessonPlanId,
      lessonPlanTitle: lessonPlanTitle ?? this.lessonPlanTitle,
      isLocked: isLocked ?? this.isLocked,
      threadCount: threadCount ?? this.threadCount,
      threads: threads ?? this.threads,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  static String encodeList(List<Forum> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<Forum> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    final result = <Forum>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        result.add(Forum.fromJson(item));
      }
    }
    return result;
  }
}
