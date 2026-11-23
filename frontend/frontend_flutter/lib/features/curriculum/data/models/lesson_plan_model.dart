import 'dart:convert';
import 'grade_level_model.dart';
import 'json_parsers.dart';
import 'lesson_components_models.dart';

class LessonAuthorEntry {
  const LessonAuthorEntry({
    this.id,
    this.userId,
    this.username = '',
    this.fullName = '',
    this.authorRole = 'Primary Author',
  });

  final int? id;
  final int? userId;
  final String username;
  final String fullName;
  final String authorRole;

  String get displayLabel {
    final name = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? '@$username' : 'User #${userId ?? ''}');
    return authorRole.isNotEmpty ? '$name ($authorRole)' : name;
  }

  factory LessonAuthorEntry.fromJson(Map<String, dynamic> json) {
    final rawAccount = json['account'] ?? json['user'] ?? json['author'];
    final accountObj =
        rawAccount is Map ? Map<String, dynamic>.from(rawAccount) : null;

    final firstName =
        asString(accountObj?['first_name'] ?? json['first_name']);
    final lastName = asString(accountObj?['last_name'] ?? json['last_name']);
    final combined = '$firstName $lastName'.trim();

    final rawRole = asString(
      json['author_role'] ?? json['checker_role'] ?? json['role'],
    );

    final resolvedUserId = asNullableInt(
      json['account_id'] ??
          accountObj?['id'] ??
          accountObj?['account_id'] ??
          accountObj?['user_id'] ??
          accountObj?['pk'] ??
          json['user_id'] ??
          json['author_id'] ??
          rawAccount,
    );

    final resolvedUsername = asString(
      accountObj?['username'] ??
          accountObj?['user_name'] ??
          json['username'] ??
          json['author_username'] ??
          json['user_username'],
    );

    return LessonAuthorEntry(
      id: asNullableInt(json['id'] ?? json['lpa_id']),
      userId: resolvedUserId,
      username: resolvedUsername,
      fullName: asString(
        json['full_name'] ??
            accountObj?['full_name'] ??
            (combined.isNotEmpty ? combined : ''),
      ),
      authorRole: rawRole.isNotEmpty ? rawRole : 'Primary Author',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': userId,
        'account': {
          'id': userId,
          'account_id': userId,
          'username': username,
          'full_name': fullName,
        },
        'user_id': userId,
        'username': username,
        'full_name': fullName,
        'author_role': authorRole,
      };
}

class LessonPlan {
  const LessonPlan({
    required this.id,
    this.serverId,
    required this.title,
    required this.subject,
    this.primaryLanguage = '',
    this.suggestedDemographic = '',
    this.learningModelDescription = '',
    this.intentionsDescription = '',
    this.notes = '',
    this.description = '',
    this.schoolName = '',
    this.teachingDate = '',
    this.quarterTerm = '',
    this.timeSessions = '',
    this.learnerContext = '',
    this.reflectionQuestions = '',
    this.authorId,
    this.authorName = '',
    this.authorIds = const [],
    this.authorEntries = const [],
    this.checkerEntries = const [],
    this.checkerName = '',
    this.isPublic = true,
    this.isApproved = false,
    this.forkedFromId,
    this.forkCount = 0,
    this.gradeLevels = const [],
    this.flows = const [],
    this.gradings = const [],
    this.materials = const [],
    this.extraFields = const {},
    this.isPendingSync = false,
    this.updatedAt,
  });

  final String id;
  final int? serverId;
  final String title;
  final String subject;
  final String primaryLanguage;
  final String suggestedDemographic;
  final String learningModelDescription;
  final String intentionsDescription;
  final String notes;
  final String description;

  final String schoolName;
  final String teachingDate;
  final String quarterTerm;
  final String timeSessions;
  final String learnerContext;
  final String reflectionQuestions;

  final int? authorId;
  final String authorName;
  final List<int> authorIds;
  final List<LessonAuthorEntry> authorEntries;
  final List<LessonAuthorEntry> checkerEntries;
  final String checkerName;
  final bool isPublic;
  final bool isApproved;
  final int? forkedFromId;
  final int forkCount;
  final List<LessonGradeLevel> gradeLevels;
  final List<LessonFlow> flows;
  final List<LessonGrading> gradings;
  final List<LessonMaterial> materials;
  final Map<String, dynamic> extraFields;
  final bool isPendingSync;
  final String? updatedAt;

  String get multigradeModel => learningModelDescription;
  String get sharedSubTheme => intentionsDescription;
  String get notesForNextSession => notes;

  bool _matchesUser(int? userId, String? username) {
    final normalizedUser = username?.trim().toLowerCase() ?? '';
    if (userId != null && userId > 0) {
      if (authorId == userId ||
          authorIds.contains(userId) ||
          authorEntries.any((e) => e.userId == userId)) {
        return true;
      }
    }
    if (normalizedUser.isNotEmpty) {
      if (authorName.trim().toLowerCase() == normalizedUser ||
          authorEntries.any(
            (e) => e.username.trim().toLowerCase() == normalizedUser,
          )) {
        return true;
      }
    }
    return false;
  }

  String primaryAuthorDisplay({int? currentUserId, String? currentUsername}) {
    if (authorEntries.isNotEmpty) {
      final primary = authorEntries.firstWhere(
        (e) =>
            !e.authorRole.toLowerCase().contains('check') &&
            !e.authorRole.toLowerCase().contains('review') &&
            !e.authorRole.toLowerCase().contains('co-author') &&
            !e.authorRole.toLowerCase().contains('contributor') &&
            !e.authorRole.toLowerCase().contains('supporting'),
        orElse: () => authorEntries.first,
      );
      if (primary.fullName.trim().isNotEmpty) return primary.fullName.trim();
      if (primary.username.trim().isNotEmpty) {
        final u = primary.username.trim();
        return u.startsWith('@') ? u : '@$u';
      }
    }
    if (authorName.trim().isNotEmpty) {
      final u = authorName.trim();
      return u.startsWith('@') ? u : '@$u';
    }
    if (currentUsername != null &&
        currentUsername.trim().isNotEmpty &&
        isCreatedBy(currentUserId, currentUsername: currentUsername)) {
      final u = currentUsername.trim();
      return u.startsWith('@') ? u : '@$u';
    }
    if (authorId != null && authorId! > 0) {
      return 'User #$authorId';
    }
    return '';
  }

  bool get isLocalDraft =>
      serverId == null && (id.startsWith('temp_') || int.tryParse(id) == null);

  bool isOwnedBy(int? currentUserId, {String? currentUsername}) {
    if (isLocalDraft) return true;
    return _matchesUser(currentUserId, currentUsername);
  }

  bool isCreatedBy(int? currentUserId, {String? currentUsername}) {
    if (isLocalDraft) return true;
    final hasValidId = currentUserId != null && currentUserId > 0;
    final normalizedUser = currentUsername?.trim().toLowerCase() ?? '';
    if (!hasValidId && normalizedUser.isEmpty) return false;

    if (hasValidId && authorId == currentUserId) return true;
    if (normalizedUser.isNotEmpty &&
        authorName.trim().toLowerCase() == normalizedUser) {
      return true;
    }

    for (final entry in authorEntries) {
      final idMatch = hasValidId && entry.userId == currentUserId;
      final nameMatch = normalizedUser.isNotEmpty &&
          entry.username.trim().toLowerCase() == normalizedUser;
      if (idMatch || nameMatch) {
        final role = entry.authorRole.toLowerCase();
        if (!role.contains('check') &&
            !role.contains('review') &&
            !role.contains('co-author') &&
            !role.contains('contributor') &&
            !role.contains('supporting')) {
          return true;
        }
      }
    }

    if (hasValidId &&
        authorId == null &&
        authorEntries.isEmpty &&
        authorIds.isNotEmpty &&
        authorIds.first == currentUserId) {
      return true;
    }
    return false;
  }

  bool isContributedBy(int? currentUserId, {String? currentUsername}) {
    if (isCreatedBy(currentUserId, currentUsername: currentUsername)) {
      return false;
    }
    final hasValidId = currentUserId != null && currentUserId > 0;
    final normalizedUser = currentUsername?.trim().toLowerCase() ?? '';
    if (!hasValidId && normalizedUser.isEmpty) return false;

    if (hasValidId && authorIds.contains(currentUserId)) return true;
    if (authorEntries.any(
      (e) =>
          (hasValidId && e.userId == currentUserId) ||
          (normalizedUser.isNotEmpty &&
              e.username.trim().toLowerCase() == normalizedUser),
    )) {
      return true;
    }
    if (checkerEntries.any(
      (e) =>
          (hasValidId && e.userId == currentUserId) ||
          (normalizedUser.isNotEmpty &&
              e.username.trim().toLowerCase() == normalizedUser),
    )) {
      return true;
    }
    return false;
  }

  String? contributionRoleFor(int? currentUserId, {String? currentUsername}) {
    if (isCreatedBy(currentUserId, currentUsername: currentUsername)) {
      return null;
    }
    final hasValidId = currentUserId != null && currentUserId > 0;
    final normalizedUser = currentUsername?.trim().toLowerCase() ?? '';
    if (!hasValidId && normalizedUser.isEmpty) return null;

    for (final entry in authorEntries) {
      final matches = (hasValidId && entry.userId == currentUserId) ||
          (normalizedUser.isNotEmpty &&
              entry.username.trim().toLowerCase() == normalizedUser);
      if (matches && entry.authorRole.isNotEmpty) {
        return entry.authorRole;
      }
    }
    for (final entry in checkerEntries) {
      final matches = (hasValidId && entry.userId == currentUserId) ||
          (normalizedUser.isNotEmpty &&
              entry.username.trim().toLowerCase() == normalizedUser);
      if (matches) {
        return entry.authorRole.isNotEmpty ? entry.authorRole : 'Checker';
      }
    }
    if (hasValidId && authorIds.contains(currentUserId)) return 'Contributor';
    return null;
  }

  String firstNonEmpty(List<String> keys) {
    for (final k in keys) {
      final v = extraFields[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  LessonPlan copyWith({
    String? id,
    int? serverId,
    String? title,
    String? subject,
    String? primaryLanguage,
    String? suggestedDemographic,
    String? learningModelDescription,
    String? intentionsDescription,
    String? notes,
    String? description,
    String? schoolName,
    String? teachingDate,
    String? quarterTerm,
    String? timeSessions,
    String? learnerContext,
    String? reflectionQuestions,
    int? authorId,
    String? authorName,
    List<int>? authorIds,
    List<LessonAuthorEntry>? authorEntries,
    List<LessonAuthorEntry>? checkerEntries,
    String? checkerName,
    bool? isPublic,
    bool? isApproved,
    int? forkedFromId,
    int? forkCount,
    List<LessonGradeLevel>? gradeLevels,
    List<LessonFlow>? flows,
    List<LessonGrading>? gradings,
    List<LessonMaterial>? materials,
    Map<String, dynamic>? extraFields,
    bool? isPendingSync,
    String? updatedAt,
  }) {
    return LessonPlan(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      suggestedDemographic: suggestedDemographic ?? this.suggestedDemographic,
      learningModelDescription:
          learningModelDescription ?? this.learningModelDescription,
      intentionsDescription:
          intentionsDescription ?? this.intentionsDescription,
      notes: notes ?? this.notes,
      description: description ?? this.description,
      schoolName: schoolName ?? this.schoolName,
      teachingDate: teachingDate ?? this.teachingDate,
      quarterTerm: quarterTerm ?? this.quarterTerm,
      timeSessions: timeSessions ?? this.timeSessions,
      learnerContext: learnerContext ?? this.learnerContext,
      reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorIds: authorIds ?? this.authorIds,
      authorEntries: authorEntries ?? this.authorEntries,
      checkerEntries: checkerEntries ?? this.checkerEntries,
      checkerName: checkerName ?? this.checkerName,
      isPublic: isPublic ?? this.isPublic,
      isApproved: isApproved ?? this.isApproved,
      forkedFromId: forkedFromId ?? this.forkedFromId,
      forkCount: forkCount ?? this.forkCount,
      gradeLevels: gradeLevels ?? this.gradeLevels,
      flows: flows ?? this.flows,
      gradings: gradings ?? this.gradings,
      materials: materials ?? this.materials,
      extraFields: extraFields ?? this.extraFields,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _knownKeys = <String>{
    'lp_id',
    'id',
    'lp_title',
    'title',
    'learning_area',
    'subject',
    'primary_language',
    'suggested_demographic',
    'learning_model_description',
    'multigrade_model',
    'intentions_description',
    'shared_sub_theme',
    'notes',
    'notes_for_next_session',
    'description',
    'school_name',
    'school',
    'teaching_date',
    'date',
    'quarter_term',
    'quarter',
    'time_sessions',
    'time',
    'learner_context',
    'l_context',
    'reflection_questions',
    'w_reflection_questions',
    'author',
    'created_by',
    'author_username',
    'author_name',
    'authors',
    'checkers',
    'checked_by',
    'checker_name',
    'is_public',
    'is_approved',
    'forked_from',
    'forked_from_id',
    'fork_count',
    'differentiated_plans',
    'grade_levels',
    'lesson_grade_levels',
    'flows',
    'lesson_flows',
    'gradings',
    'lesson_gradings',
    'materials',
    'isPendingSync',
    'updated_at',
  };

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final numericId = asNullableInt(json['lp_id'] ?? json['id']);
    final rawId = json['lp_id'] ?? json['id'];

    final entries = <LessonAuthorEntry>[];
    final ids = <int>[];
    final rawAuthors = json['authors'] ?? json['lesson_plan_authors'];
    if (rawAuthors is List) {
      for (final a in rawAuthors) {
        if (a is Map) {
          final entry =
              LessonAuthorEntry.fromJson(Map<String, dynamic>.from(a));
          entries.add(entry);
          if (entry.userId != null && !ids.contains(entry.userId)) {
            ids.add(entry.userId!);
          }
        } else {
          final directId = asNullableInt(a);
          if (directId != null && !ids.contains(directId)) {
            ids.add(directId);
          }
        }
      }
    }

    final checkers = <LessonAuthorEntry>[];
    final rawCheckers = json['checkers'];
    if (rawCheckers is List) {
      for (final c in rawCheckers) {
        if (c is Map) {
          checkers.add(
            LessonAuthorEntry.fromJson(Map<String, dynamic>.from(c)),
          );
        }
      }
    }

    int? primaryAuthorId;
    String resolvedAuthorName =
        asString(json['author_username'] ?? json['author_name']);
    final authorField = json['author'] ?? json['created_by'];
    final directAuthorId = asNullableInt(authorField);
    if (directAuthorId != null) {
      primaryAuthorId = directAuthorId;
    } else if (authorField is Map) {
      final authorMap = Map<String, dynamic>.from(authorField);
      primaryAuthorId = asNullableInt(
        authorMap['id'] ?? authorMap['account_id'] ?? authorMap['pk'],
      );
      if (resolvedAuthorName.isEmpty) {
        resolvedAuthorName = asString(
          authorMap['username'] ?? authorMap['full_name'],
        );
      }
    }

    if (primaryAuthorId == null && entries.isNotEmpty) {
      final primaryEntry = entries.firstWhere(
        (e) =>
            !e.authorRole.toLowerCase().contains('check') &&
            !e.authorRole.toLowerCase().contains('review') &&
            !e.authorRole.toLowerCase().contains('co-author') &&
            !e.authorRole.toLowerCase().contains('contributor') &&
            !e.authorRole.toLowerCase().contains('supporting'),
        orElse: () => entries.first,
      );
      primaryAuthorId = primaryEntry.userId;
    }
    if (primaryAuthorId == null && ids.isNotEmpty) {
      primaryAuthorId = ids.first;
    }
    if (resolvedAuthorName.isEmpty && entries.isNotEmpty) {
      final primaryEntry = entries.firstWhere(
        (e) =>
            !e.authorRole.toLowerCase().contains('check') &&
            !e.authorRole.toLowerCase().contains('review') &&
            !e.authorRole.toLowerCase().contains('co-author') &&
            !e.authorRole.toLowerCase().contains('contributor') &&
            !e.authorRole.toLowerCase().contains('supporting'),
        orElse: () => entries.first,
      );
      resolvedAuthorName = primaryEntry.username.isNotEmpty
          ? primaryEntry.username
          : primaryEntry.fullName;
    }

    String resolvedCheckerName = asString(json['checker_name']);
    final checkerField = json['checked_by'];
    if (resolvedCheckerName.isEmpty && checkerField is Map) {
      final checkerMap = Map<String, dynamic>.from(checkerField);
      resolvedCheckerName = asString(
        checkerMap['full_name'] ?? checkerMap['username'],
      );
    }
    if (resolvedCheckerName.isEmpty && checkers.isNotEmpty) {
      resolvedCheckerName = checkers.first.fullName.isNotEmpty
          ? checkers.first.fullName
          : '@${checkers.first.username}';
    }

    final diffList = json['differentiated_plans'];
    final rawGradeSource = (diffList is List && diffList.isNotEmpty)
        ? diffList
        : (json['lesson_grade_levels'] ?? json['grade_levels']);

    final parsedGradeLevels = parseModelList(
      rawGradeSource,
      LessonGradeLevel.fromJson,
    );

    final topFlows = parseModelList(
      json['lesson_flows'] ?? json['flows'],
      LessonFlow.fromJson,
    );
    final nestedFlows = parsedGradeLevels.expand((g) => g.flows).toList();
    final combinedFlows = topFlows.isNotEmpty ? topFlows : nestedFlows;

    final topGradings = parseModelList(
      json['lesson_gradings'] ?? json['gradings'],
      LessonGrading.fromJson,
    );
    final nestedGradings =
        parsedGradeLevels.expand((g) => g.gradingTasks).toList();
    final combinedGradings =
        topGradings.isNotEmpty ? topGradings : nestedGradings;

    final topMaterials = parseModelList(
      json['materials'],
      LessonMaterial.fromJson,
    );
    final nestedMaterials =
        parsedGradeLevels.expand((g) => g.materials).toList();
    final combinedMaterials =
        topMaterials.isNotEmpty ? topMaterials : nestedMaterials;

    final rawExtra = json['extraFields'] is Map
        ? Map<String, dynamic>.from(json['extraFields'] as Map)
        : <String, dynamic>{};

    for (final entry in json.entries) {
      if (!_knownKeys.contains(entry.key) &&
          entry.value != null &&
          entry.value.toString().trim().isNotEmpty) {
        rawExtra[entry.key] = entry.value;
      }
    }

    final demographic = asString(json['suggested_demographic']);
    final desc = asString(json['description']);

    return LessonPlan(
      id: numericId?.toString() ?? asString(rawId),
      serverId: numericId,
      title: asString(json['lp_title'] ?? json['title']),
      subject: asString(json['learning_area'] ?? json['subject']),
      primaryLanguage: asString(json['primary_language']),
      suggestedDemographic: demographic,
      learningModelDescription: asString(
        json['learning_model_description'] ?? json['multigrade_model'],
      ),
      intentionsDescription: asString(
        json['intentions_description'] ?? json['shared_sub_theme'],
      ),
      notes: asString(json['notes'] ?? json['notes_for_next_session']),
      description: desc.isNotEmpty ? desc : demographic,
      schoolName: asString(json['school_name'] ?? json['school']),
      teachingDate: asString(json['teaching_date'] ?? json['date']),
      quarterTerm: asString(json['quarter_term'] ?? json['quarter']),
      timeSessions: asString(json['time_sessions'] ?? json['time']),
      learnerContext: asString(json['learner_context'] ?? json['l_context']),
      reflectionQuestions: asString(
        json['reflection_questions'] ?? json['w_reflection_questions'],
      ),
      authorId: primaryAuthorId,
      authorName: resolvedAuthorName,
      authorIds: ids,
      authorEntries: entries,
      checkerEntries: checkers,
      checkerName: resolvedCheckerName,
      isPublic: json['is_public'] is bool ? json['is_public'] as bool : true,
      isApproved:
          json['is_approved'] is bool ? json['is_approved'] as bool : false,
      forkedFromId:
          asNullableInt(json['forked_from'] ?? json['forked_from_id']),
      forkCount: asInt(json['fork_count']),
      gradeLevels: parsedGradeLevels,
      flows: combinedFlows,
      gradings: combinedGradings,
      materials: combinedMaterials,
      extraFields: rawExtra,
      isPendingSync: json['isPendingSync'] == true,
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lp_id': serverId ?? id,
        'lp_title': title,
        'learning_area': subject,
        'primary_language': primaryLanguage,
        'suggested_demographic': suggestedDemographic,
        'learning_model_description': learningModelDescription,
        'intentions_description': intentionsDescription,
        'notes': notes,
        'description': description,
        'school_name': schoolName,
        'teaching_date': teachingDate,
        'quarter_term': quarterTerm,
        'time_sessions': timeSessions,
        'learner_context': learnerContext,
        'reflection_questions': reflectionQuestions,
        'author': authorId,
        'author_username': authorName,
        'authors': authorEntries.isNotEmpty
            ? authorEntries.map((e) => e.toJson()).toList()
            : authorIds,
        if (checkerEntries.isNotEmpty)
          'checkers': checkerEntries.map((e) => e.toJson()).toList(),
        'checker_name': checkerName,
        'is_public': isPublic,
        'is_approved': isApproved,
        'forked_from': forkedFromId,
        'fork_count': forkCount,
        'differentiated_plans': gradeLevels.map((e) => e.toJson()).toList(),
        'lesson_flows': flows.map((e) => e.toJson()).toList(),
        'lesson_gradings': gradings.map((e) => e.toJson()).toList(),
        'materials': materials.map((e) => e.toJson()).toList(),
        if (extraFields.isNotEmpty) 'extraFields': extraFields,
        'isPendingSync': isPendingSync,
        'updated_at': updatedAt,
      };

  static String encodeList(List<LessonPlan> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<LessonPlan> decodeList(String raw) =>
      parseModelList(jsonDecode(raw), LessonPlan.fromJson);
}
