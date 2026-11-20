import 'dart:convert';
import 'grade_level_model.dart';
import 'json_parsers.dart';
import 'lesson_components_models.dart';

class LessonAuthorEntry {
  const LessonAuthorEntry({
    required this.username,
    this.fullName = '',
    this.authorRole = 'Author',
    this.userId,
  });

  final String username;
  final String fullName;
  final String authorRole;
  final int? userId;

  String get displayLabel =>
      fullName.isNotEmpty ? '$fullName (@$username)' : '@$username';
}

class LessonPlan {
  const LessonPlan({
    required this.id,
    required this.title,
    required this.subject,
    this.primaryLanguage = 'English',
    this.suggestedDemographic = '',
    this.schoolName = '',
    this.teachingDate = '',
    this.quarterTerm = '',
    this.timeSessions = '',
    this.multigradeModel = '',
    this.sharedSubTheme = '',
    this.learnerContext = '',
    this.reflectionQuestions = '',
    this.notesForNextSession = '',
    this.description = '',
    this.authorId,
    this.authorName = '',
    this.authorEntries = const [],
    this.authorIds = const [],
    this.checkerId,
    this.checkerName = '',
    this.isApproved = false,
    this.isPublic = true,
    this.forkedFromId,
    this.forkCount = 0,
    this.gradeLevels = const [],
    this.flows = const [],
    this.gradings = const [],
    this.materials = const [],
    this.extraFields = const {},
    this.isPendingSync = false,
  });

  final String id;
  final String title;
  final String subject;
  final String primaryLanguage;
  final String suggestedDemographic;
  final String schoolName;
  final String teachingDate;
  final String quarterTerm;
  final String timeSessions;
  final String multigradeModel;
  final String sharedSubTheme;
  final String learnerContext;
  final String reflectionQuestions;
  final String notesForNextSession;
  final String description;
  final int? authorId;
  final String authorName;
  final List<LessonAuthorEntry> authorEntries;
  final List<int> authorIds;
  final int? checkerId;
  final String checkerName;
  final bool isApproved;
  final bool isPublic;
  final int? forkedFromId;
  final int forkCount;
  final List<LessonGradeLevel> gradeLevels;
  final List<LessonFlow> flows;
  final List<LessonGrading> gradings;
  final List<LessonMaterial> materials;
  final Map<String, dynamic> extraFields;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  bool isOwnedBy(int? userId) {
    if (userId == null) return false;
    return authorId == userId || authorIds.contains(userId);
  }

  /// True when [userId] created this plan (primary author or local draft).
  bool isCreatedBy(int? userId) {
    if (isLocalDraft) return true;
    if (userId == null) return false;

    final userEntries =
        authorEntries.where((e) => e.userId == userId).toList();
    if (userEntries.isNotEmpty) {
      final hasPrimaryRole = userEntries.any((e) {
        final role = e.authorRole.trim().toLowerCase();
        return role.isEmpty ||
            role == 'author' ||
            role == 'primary' ||
            role == 'primary author' ||
            role == 'creator';
      });
      if (hasPrimaryRole) return true;
      if (authorEntries.first.userId == userId) return true;
      return false;
    }

    return authorId == userId ||
        (authorIds.isNotEmpty && authorIds.first == userId);
  }

  /// True when [userId] participated as checker, co-author, or secondary contributor
  /// without being the primary creator.
  bool isContributedBy(int? userId) {
    if (userId == null || isCreatedBy(userId)) return false;
    if (checkerId == userId) return true;
    if (authorIds.contains(userId)) return true;
    return authorEntries.any((e) => e.userId == userId);
  }

  /// Human-readable role badge for [userId] when [isContributedBy] is true.
  String? contributionRoleFor(int? userId) {
    if (userId == null) return null;
    final roles = <String>[];
    for (final entry in authorEntries) {
      if (entry.userId == userId && entry.authorRole.trim().isNotEmpty) {
        roles.add(entry.authorRole.trim());
      }
    }
    if (roles.isEmpty && authorIds.contains(userId)) {
      roles.add('Co-Author');
    }
    if (checkerId == userId) {
      roles.add('Checker');
    }
    if (roles.isEmpty) return null;
    return roles.toSet().join(' • ');
  }

  static const Set<String> _knownKeys = {
    'lp_id', 'id', 'pk', 'lp_title', 'title', 'name',
    'learning_area', 'subject', 'subject_area',
    'primary_language', 'suggested_demographic',
    'school', 'school_name', 'teaching_date', 'quarter_term', 'quarter', 'term',
    'time_sessions', 'duration', 'sessions',
    'multigrade_model', 'shared_sub_theme', 'sub_theme',
    'learner_context', 'l_context', 'reflection_questions', 'w_reflection_questions',
    'notes_for_next_session', 'next_session_notes',
    'description', 'overview',
    'authors', 'author', 'author_detail', 'author_username', 'author_name',
    'checker', 'checker_detail', 'checker_username', 'checker_name',
    'is_approved', 'is_public', 'forked_from', 'fork_count',
    'grade_levels', 'lesson_grade_levels',
    'lesson_flows', 'flows', 'lesson_gradings', 'gradings', 'grading_tasks',
    'materials', 'lesson_materials', 'is_pending_sync',
  };

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final parsedAuthors = _parseAuthors(json);
    final checkerObj = json['checker_detail'] ?? json['checker'];
    final int? cId = asNullableInt(checkerObj);
    String cName = asString(json['checker_username'] ?? json['checker_name']);
    if (checkerObj is Map<String, dynamic> && cName.isEmpty) {
      final fn = asString(checkerObj['first_name']);
      final ln = asString(checkerObj['last_name']);
      final full = '$fn $ln'.trim();
      cName = full.isNotEmpty ? full : asString(checkerObj['username']);
    }

    final extras = <String, dynamic>{};
    json.forEach((key, value) {
      if (!_knownKeys.contains(key) &&
          value != null &&
          value.toString().trim().isNotEmpty) {
        extras[key] = value;
      }
    });

    final parsedGradeLevels = parseModelList(
      json['lesson_grade_levels'] ?? json['grade_levels'],
      LessonGradeLevel.fromJson,
    );

    final lglLookup = <String, String>{
      for (final gl in parsedGradeLevels)
        gl.id: gl.gradeLevelName.isNotEmpty
            ? gl.gradeLevelName
            : 'Grade ${gl.gradeLevelId}',
    };

    var parsedFlows = parseModelList(
      json['lesson_flows'] ?? json['flows'],
      LessonFlow.fromJson,
    );
    if (parsedFlows.isEmpty) {
      parsedFlows = parsedGradeLevels.expand((gl) => gl.flows).toList();
    }
    parsedFlows = parsedFlows.map((f) {
      if (f.gradeLevelName.isEmpty &&
          f.lessonGradeLevelId != null &&
          lglLookup.containsKey(f.lessonGradeLevelId)) {
        return f.copyWith(gradeLevelName: lglLookup[f.lessonGradeLevelId]!);
      }
      return f;
    }).toList();

    var parsedGradings = parseModelList(
      json['lesson_gradings'] ?? json['grading_tasks'] ?? json['gradings'],
      LessonGrading.fromJson,
    );
    if (parsedGradings.isEmpty) {
      parsedGradings =
          parsedGradeLevels.expand((gl) => gl.gradingTasks).toList();
    }
    parsedGradings = parsedGradings.map((g) {
      if (g.gradeLevelName.isEmpty &&
          g.lessonGradeLevelId != null &&
          lglLookup.containsKey(g.lessonGradeLevelId)) {
        return g.copyWith(gradeLevelName: lglLookup[g.lessonGradeLevelId]!);
      }
      return g;
    }).toList();

    var parsedMaterials = parseModelList(
      json['materials'] ?? json['lesson_materials'],
      LessonMaterial.fromJson,
    );
    if (parsedMaterials.isEmpty) {
      parsedMaterials = parsedGradeLevels.expand((gl) => gl.materials).toList();
    }
    parsedMaterials = parsedMaterials.map((m) {
      if (m.gradeLevelName.isEmpty &&
          m.lessonGradeLevelId != null &&
          lglLookup.containsKey(m.lessonGradeLevelId)) {
        return m.copyWith(gradeLevelName: lglLookup[m.lessonGradeLevelId]!);
      }
      return m;
    }).toList();

    return LessonPlan(
      id: asString(json['lp_id'] ?? json['id'] ?? json['pk']),
      title: asString(json['lp_title'] ?? json['title'] ?? json['name']),
      subject: asString(
        json['learning_area'] ?? json['subject'] ?? json['subject_area'],
      ),
      primaryLanguage: asString(json['primary_language'], 'English'),
      suggestedDemographic: asString(json['suggested_demographic']),
      schoolName: asString(json['school_name'] ?? json['school']),
      teachingDate: asString(json['teaching_date']),
      quarterTerm: asString(
        json['quarter_term'] ?? json['quarter'] ?? json['term'],
      ),
      timeSessions: asString(json['time_sessions'] ?? json['sessions']),
      multigradeModel: asString(json['multigrade_model']),
      sharedSubTheme: asString(json['shared_sub_theme'] ?? json['sub_theme']),
      learnerContext: asString(json['learner_context'] ?? json['l_context']),
      reflectionQuestions: asString(
        json['reflection_questions'] ?? json['w_reflection_questions'],
      ),
      notesForNextSession: asString(
        json['notes_for_next_session'] ?? json['next_session_notes'],
      ),
      description: asString(json['description'] ?? json['overview']),
      authorId: parsedAuthors.primaryId,
      authorName: parsedAuthors.displayNames,
      authorEntries: parsedAuthors.entries,
      authorIds: parsedAuthors.ids,
      checkerId: cId,
      checkerName: cName,
      isApproved: asBool(json['is_approved']),
      isPublic: asBool(json['is_public'], true),
      forkedFromId: asNullableInt(json['forked_from']),
      forkCount: asInt(json['fork_count']),
      gradeLevels: parsedGradeLevels,
      flows: parsedFlows,
      gradings: parsedGradings,
      materials: parsedMaterials,
      extraFields: extras,
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  static ({
    int? primaryId,
    String displayNames,
    List<LessonAuthorEntry> entries,
    List<int> ids,
  }) _parseAuthors(Map<String, dynamic> json) {
    int? aId;
    String aName = asString(json['author_username'] ?? json['author_name']);
    final ids = <int>[];
    final entries = <LessonAuthorEntry>[];

    final authorsList = json['authors'];
    if (authorsList is List && authorsList.isNotEmpty) {
      final names = <String>[];
      for (final item in authorsList) {
        if (item is Map<String, dynamic>) {
          final role = asString(item['author_role'], 'Author');
          final acct = item['account'];
          if (acct is Map<String, dynamic>) {
            final uid = asNullableInt(acct['id'] ?? acct['user_id']);
            final uname = asString(acct['username']);
            final full =
                '${asString(acct['first_name'])} ${asString(acct['last_name'])}'
                    .trim();
            if (uid != null) {
              ids.add(uid);
              aId ??= uid;
            }
            if (uname.isNotEmpty || full.isNotEmpty) {
              names.add(full.isNotEmpty ? full : uname);
              entries.add(LessonAuthorEntry(
                username: uname,
                fullName: full,
                authorRole: role,
                userId: uid,
              ));
            }
          } else {
            final uid =
                asNullableInt(item['account'] ?? item['user_id'] ?? item['id']);
            final uname = asString(item['username']);
            if (uid != null) {
              ids.add(uid);
              aId ??= uid;
            }
            if (uname.isNotEmpty) {
              names.add(uname);
              entries.add(LessonAuthorEntry(
                username: uname,
                authorRole: role,
                userId: uid,
              ));
            }
          }
        }
      }
      if (names.isNotEmpty) aName = names.join(', ');
    }

    final authorObj = json['author_detail'] ?? json['author'];
    if (aId == null && authorObj != null) {
      aId = asNullableInt(authorObj);
      if (aId != null) ids.add(aId);
      if (authorObj is Map<String, dynamic> && aName.isEmpty) {
        aName = asString(authorObj['username']);
      }
    }

    return (primaryId: aId, displayNames: aName, entries: entries, ids: ids);
  }

  Map<String, dynamic> toJson() => {
        ...extraFields,
        'lp_id': id,
        'lp_title': title,
        'learning_area': subject,
        'primary_language': primaryLanguage,
        'suggested_demographic': suggestedDemographic,
        'school_name': schoolName,
        'teaching_date': teachingDate,
        'quarter_term': quarterTerm,
        'time_sessions': timeSessions,
        'multigrade_model': multigradeModel,
        'shared_sub_theme': sharedSubTheme,
        'learner_context': learnerContext,
        'reflection_questions': reflectionQuestions,
        'notes_for_next_session': notesForNextSession,
        'description': description,
        'author': authorId,
        'author_username': authorName,
        if (authorEntries.isNotEmpty)
          'authors': authorEntries
              .map((e) => {
                    'author_role': e.authorRole,
                    'account': {
                      if (e.userId != null) 'id': e.userId,
                      'username': e.username,
                      'first_name': e.fullName,
                    },
                  })
              .toList(),
        'checker': checkerId,
        'checker_username': checkerName,
        'is_approved': isApproved,
        'is_public': isPublic,
        'forked_from': forkedFromId,
        'fork_count': forkCount,
        'lesson_grade_levels': gradeLevels.map((e) => e.toJson()).toList(),
        'lesson_flows': flows.map((e) => e.toJson()).toList(),
        'lesson_gradings': gradings.map((e) => e.toJson()).toList(),
        'materials': materials.map((e) => e.toJson()).toList(),
        'is_pending_sync': isPendingSync,
      };

  LessonPlan copyWith({
    String? id,
    String? title,
    String? subject,
    String? primaryLanguage,
    String? suggestedDemographic,
    String? schoolName,
    String? teachingDate,
    String? quarterTerm,
    String? timeSessions,
    String? multigradeModel,
    String? sharedSubTheme,
    String? learnerContext,
    String? reflectionQuestions,
    String? notesForNextSession,
    String? description,
    int? authorId,
    String? authorName,
    List<LessonAuthorEntry>? authorEntries,
    List<int>? authorIds,
    int? checkerId,
    String? checkerName,
    bool? isApproved,
    bool? isPublic,
    int? forkedFromId,
    int? forkCount,
    List<LessonGradeLevel>? gradeLevels,
    List<LessonFlow>? flows,
    List<LessonGrading>? gradings,
    List<LessonMaterial>? materials,
    Map<String, dynamic>? extraFields,
    bool? isPendingSync,
  }) {
    return LessonPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      suggestedDemographic: suggestedDemographic ?? this.suggestedDemographic,
      schoolName: schoolName ?? this.schoolName,
      teachingDate: teachingDate ?? this.teachingDate,
      quarterTerm: quarterTerm ?? this.quarterTerm,
      timeSessions: timeSessions ?? this.timeSessions,
      multigradeModel: multigradeModel ?? this.multigradeModel,
      sharedSubTheme: sharedSubTheme ?? this.sharedSubTheme,
      learnerContext: learnerContext ?? this.learnerContext,
      reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
      notesForNextSession: notesForNextSession ?? this.notesForNextSession,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorEntries: authorEntries ?? this.authorEntries,
      authorIds: authorIds ?? this.authorIds,
      checkerId: checkerId ?? this.checkerId,
      checkerName: checkerName ?? this.checkerName,
      isApproved: isApproved ?? this.isApproved,
      isPublic: isPublic ?? this.isPublic,
      forkedFromId: forkedFromId ?? this.forkedFromId,
      forkCount: forkCount ?? this.forkCount,
      gradeLevels: gradeLevels ?? this.gradeLevels,
      flows: flows ?? this.flows,
      gradings: gradings ?? this.gradings,
      materials: materials ?? this.materials,
      extraFields: extraFields ?? this.extraFields,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  static String encodeList(List<LessonPlan> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<LessonPlan> decodeList(String raw) =>
      parseModelList(jsonDecode(raw), LessonPlan.fromJson);
}
