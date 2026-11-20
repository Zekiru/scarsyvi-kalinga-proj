import 'dart:convert';

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  if (v is Map<String, dynamic>) {
    return _asNullableInt(
      v['id'] ?? v['lp_id'] ?? v['gl_id'] ?? v['grade_level_id'] ?? v['user_id'],
    );
  }
  return null;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

class GradeLevel {
  const GradeLevel({
    required this.id,
    required this.name,
    this.levelOrder = 0,
    this.description = '',
  });

  final int id;
  final String name;
  final int levelOrder;
  final String description;

  factory GradeLevel.fromJson(Map<String, dynamic> json) {
    return GradeLevel(
      id: _asInt(json['gl_id'] ?? json['grade_level_id'] ?? json['id'] ?? json['pk']),
      name: _asString(json['grade_level_name'] ?? json['name'] ?? json['grade_name']),
      levelOrder: _asInt(json['level_order'] ?? json['order']),
      description: _asString(json['description']),
    );
  }

  Map<String, dynamic> toJson() => {
        'gl_id': id,
        'grade_level_name': name,
        'level_order': levelOrder,
        'description': description,
      };
}

class LessonGradeLevel {
  const LessonGradeLevel({
    required this.id,
    required this.lessonPlanId,
    required this.gradeLevelId,
    this.gradeLevelName = '',
    this.specificObjectives = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final int gradeLevelId;
  final String gradeLevelName;
  final String specificObjectives;
  final bool isPendingSync;

  factory LessonGradeLevel.fromJson(Map<String, dynamic> json) {
    final glObj = json['grade_level_detail'] ?? json['grade_level'];
    int glId = _asInt(json['gl_id']);
    String glName = _asString(json['grade_level_name']);

    if (glObj is Map<String, dynamic>) {
      glId = _asInt(glObj['gl_id'] ?? glObj['id'] ?? glObj['grade_level_id'], glId);
      glName = _asString(
        glObj['grade_level_name'] ?? glObj['name'] ?? glObj['grade_name'],
        glName,
      );
    } else if (glObj != null && glId == 0) {
      glId = _asInt(glObj);
    }

    return LessonGradeLevel(
      id: _asString(
        json['lesson_grade_level_id'] ?? json['id'] ?? json['gl_id'] ?? json['pk'],
      ),
      lessonPlanId: _asString(json['lesson_plan'] ?? json['lp_id']),
      gradeLevelId: glId,
      gradeLevelName: glName,
      specificObjectives: _asString(json['specific_objectives'] ?? json['objectives']),
      isPendingSync: _asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'gl_id': gradeLevelId,
        'grade_level': gradeLevelId,
        'grade_level_name': gradeLevelName,
        'specific_objectives': specificObjectives,
        'is_pending_sync': isPendingSync,
      };
}

class LessonFlow {
  const LessonFlow({
    required this.id,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    required this.stepOrder,
    required this.phaseName,
    required this.activityDescription,
    this.durationMinutes = 10,
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final int stepOrder;
  final String phaseName;
  final String activityDescription;
  final int durationMinutes;
  final bool isPendingSync;

  factory LessonFlow.fromJson(Map<String, dynamic> json) {
    return LessonFlow(
      id: _asString(json['lesson_flow_id'] ?? json['flow_id'] ?? json['id'] ?? json['pk']),
      lessonPlanId: _asString(json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      stepOrder: _asInt(json['step_order'] ?? json['order'], 1),
      phaseName: _asString(json['phase_name'] ?? json['phase'] ?? json['title']),
      activityDescription: _asString(
        json['activity_description'] ?? json['activity'] ?? json['description'],
      ),
      durationMinutes: _asInt(json['duration_minutes'] ?? json['duration'], 10),
      isPendingSync: _asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'step_order': stepOrder,
        'phase_name': phaseName,
        'activity_description': activityDescription,
        'duration_minutes': durationMinutes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonGrading {
  const LessonGrading({
    required this.id,
    required this.lessonPlanId,
    this.lessonGradeLevelId,
    required this.criteriaName,
    required this.weightPercentage,
    this.rubricNotes = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String? lessonGradeLevelId;
  final String criteriaName;
  final double weightPercentage;
  final String rubricNotes;
  final bool isPendingSync;

  factory LessonGrading.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_percentage'] ?? json['weight'] ?? 0;
    return LessonGrading(
      id: _asString(
        json['lesson_grading_id'] ?? json['grading_id'] ?? json['id'] ?? json['pk'],
      ),
      lessonPlanId: _asString(json['lesson_plan'] ?? json['lp_id']),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      criteriaName: _asString(
        json['criteria_name'] ?? json['criterion'] ?? json['title'],
      ),
      weightPercentage: rawWeight is num
          ? rawWeight.toDouble()
          : double.tryParse(rawWeight.toString()) ?? 0.0,
      rubricNotes: _asString(json['rubric_notes'] ?? json['description']),
      isPendingSync: _asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'lesson_grade_level': lessonGradeLevelId,
        'criteria_name': criteriaName,
        'weight_percentage': weightPercentage,
        'rubric_notes': rubricNotes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonMaterial {
  const LessonMaterial({
    required this.id,
    required this.lessonPlanId,
    required this.title,
    this.materialType = 'DOCUMENT',
    this.resourceUrl = '',
    this.notes = '',
    this.isPendingSync = false,
  });

  final String id;
  final String lessonPlanId;
  final String title;
  final String materialType;
  final String resourceUrl;
  final String notes;
  final bool isPendingSync;

  factory LessonMaterial.fromJson(Map<String, dynamic> json) {
    return LessonMaterial(
      id: _asString(json['material_id'] ?? json['id'] ?? json['pk']),
      lessonPlanId: _asString(json['lesson_plan'] ?? json['lp_id']),
      title: _asString(json['title'] ?? json['material_title'] ?? json['name']),
      materialType: _asString(json['material_type'] ?? json['type'], 'DOCUMENT'),
      resourceUrl: _asString(json['resource_url'] ?? json['url'] ?? json['file']),
      notes: _asString(json['notes'] ?? json['description']),
      isPendingSync: _asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
        'title': title,
        'material_type': materialType,
        'resource_url': resourceUrl,
        'notes': notes,
        'is_pending_sync': isPendingSync,
      };
}

class LessonPlan {
  const LessonPlan({
    required this.id,
    required this.title,
    required this.subject,
    this.primaryLanguage = 'English',
    this.suggestedDemographic = '',
    this.description = '',
    this.authorId,
    this.authorName = '',
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
    this.isPendingSync = false,
  });

  final String id;
  final String title;
  final String subject;
  final String primaryLanguage;
  final String suggestedDemographic;
  final String description;
  final int? authorId;
  final String authorName;
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
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  bool isOwnedBy(int? userId) {
    if (userId == null) return false;
    return authorId == userId || authorIds.contains(userId);
  }

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    int? aId;
    String aName = _asString(json['author_username'] ?? json['author_name']);
    final collectedAuthorIds = <int>[];

    // 1. Parse `authors` list: [{ "id": 1, "account": { "id": 1, "username": "Zekiru" }, "author_role": "Primary Author" }]
    final authorsList = json['authors'];
    if (authorsList is List && authorsList.isNotEmpty) {
      final names = <String>[];
      for (final entry in authorsList) {
        if (entry is Map<String, dynamic>) {
          final acct = entry['account'];
          if (acct is Map<String, dynamic>) {
            final uid = _asNullableInt(acct['id'] ?? acct['user_id']);
            if (uid != null) {
              collectedAuthorIds.add(uid);
              aId ??= uid;
            }
            final uname = _asString(acct['username']);
            if (uname.isNotEmpty) names.add(uname);
          } else {
            final uid = _asNullableInt(entry['account'] ?? entry['user_id'] ?? entry['id']);
            if (uid != null) {
              collectedAuthorIds.add(uid);
              aId ??= uid;
            }
            final uname = _asString(entry['username']);
            if (uname.isNotEmpty) names.add(uname);
          }
        }
      }
      if (names.isNotEmpty) {
        aName = names.join(', ');
      }
    }

    // 2. Fallback to single `author` / `author_detail` field
    final authorObj = json['author_detail'] ?? json['author'];
    if (aId == null && authorObj != null) {
      aId = _asNullableInt(authorObj);
      if (aId != null) collectedAuthorIds.add(aId);
      if (authorObj is Map<String, dynamic> && aName.isEmpty) {
        aName = _asString(authorObj['username']);
      }
    }

    final checkerObj = json['checker_detail'] ?? json['checker'];
    final int? cId = _asNullableInt(checkerObj);
    String cName = _asString(json['checker_username'] ?? json['checker_name']);
    if (checkerObj is Map<String, dynamic> && cName.isEmpty) {
      cName = _asString(checkerObj['username']);
    }

    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parser) {
      if (raw is! List) return const [];
      final result = <T>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          result.add(parser(item));
        }
      }
      return result;
    }

    final demographic = _asString(json['suggested_demographic']);
    final desc = _asString(json['description'] ?? json['overview']);

    return LessonPlan(
      id: _asString(json['lp_id'] ?? json['id'] ?? json['pk']),
      title: _asString(json['lp_title'] ?? json['title'] ?? json['name']),
      subject: _asString(json['learning_area'] ?? json['subject'] ?? json['subject_area']),
      primaryLanguage: _asString(json['primary_language'], 'English'),
      suggestedDemographic: demographic,
      description: desc.isNotEmpty ? desc : demographic,
      authorId: aId,
      authorName: aName,
      authorIds: collectedAuthorIds,
      checkerId: cId,
      checkerName: cName,
      isApproved: _asBool(json['is_approved']),
      isPublic: _asBool(json['is_public'], true),
      forkedFromId: _asNullableInt(json['forked_from']),
      forkCount: _asInt(json['fork_count']),
      gradeLevels: parseList(
        json['grade_levels'] ?? json['lesson_grade_levels'],
        LessonGradeLevel.fromJson,
      ),
      flows: parseList(
        json['lesson_flows'] ?? json['flows'],
        LessonFlow.fromJson,
      ),
      gradings: parseList(
        json['lesson_gradings'] ?? json['gradings'],
        LessonGrading.fromJson,
      ),
      materials: parseList(
        json['materials'] ?? json['lesson_materials'],
        LessonMaterial.fromJson,
      ),
      isPendingSync: _asBool(json['is_pending_sync']),
    );
  }

  Map<String, dynamic> toJson() => {
        'lp_id': id,
        'lp_title': title,
        'learning_area': subject,
        'primary_language': primaryLanguage,
        'suggested_demographic': suggestedDemographic,
        'description': description,
        'author': authorId,
        'author_username': authorName,
        'checker': checkerId,
        'checker_username': checkerName,
        'is_approved': isApproved,
        'is_public': isPublic,
        'forked_from': forkedFromId,
        'fork_count': forkCount,
        'grade_levels': gradeLevels.map((e) => e.toJson()).toList(),
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
    String? description,
    int? authorId,
    String? authorName,
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
    bool? isPendingSync,
  }) {
    return LessonPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      suggestedDemographic: suggestedDemographic ?? this.suggestedDemographic,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
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
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  static String encodeList(List<LessonPlan> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<LessonPlan> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    final result = <LessonPlan>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        result.add(LessonPlan.fromJson(item));
      }
    }
    return result;
  }
}
