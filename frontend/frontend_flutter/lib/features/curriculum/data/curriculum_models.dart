import 'dart:convert';

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
      id: (json['grade_level_id'] ?? json['id'] ?? json['pk']) as int,
      name: (json['name'] ?? json['grade_name'] ?? '') as String,
      levelOrder: (json['level_order'] ?? json['order'] ?? 0) as int,
      description: (json['description'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
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

  final String id; // Stringified server PK or `temp_lgl_*`
  final String lessonPlanId;
  final int gradeLevelId;
  final String gradeLevelName;
  final String specificObjectives;
  final bool isPendingSync;

  factory LessonGradeLevel.fromJson(Map<String, dynamic> json) {
    final glObj = json['grade_level_detail'] ?? json['grade_level'];
    int glId = 0;
    String glName = (json['grade_level_name'] ?? '') as String;

    if (glObj is int) {
      glId = glObj;
    } else if (glObj is Map<String, dynamic>) {
      glId = (glObj['id'] ?? glObj['grade_level_id'] ?? 0) as int;
      glName = (glObj['name'] ?? glObj['grade_name'] ?? glName) as String;
    }

    return LessonGradeLevel(
      id: (json['lesson_grade_level_id'] ?? json['id'] ?? '').toString(),
      lessonPlanId: (json['lesson_plan'] ?? '').toString(),
      gradeLevelId: glId,
      gradeLevelName: glName,
      specificObjectives: (json['specific_objectives'] ?? '') as String,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_plan': lessonPlanId,
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
      id: (json['lesson_flow_id'] ?? json['id'] ?? '').toString(),
      lessonPlanId: (json['lesson_plan'] ?? '').toString(),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      stepOrder: (json['step_order'] ?? json['order'] ?? 1) as int,
      phaseName: (json['phase_name'] ?? json['title'] ?? '') as String,
      activityDescription:
          (json['activity_description'] ?? json['description'] ?? '') as String,
      durationMinutes: (json['duration_minutes'] ?? 10) as int,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
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
      id: (json['lesson_grading_id'] ?? json['id'] ?? '').toString(),
      lessonPlanId: (json['lesson_plan'] ?? '').toString(),
      lessonGradeLevelId: json['lesson_grade_level']?.toString(),
      criteriaName: (json['criteria_name'] ?? json['title'] ?? '') as String,
      weightPercentage: rawWeight is num
          ? rawWeight.toDouble()
          : double.tryParse(rawWeight.toString()) ?? 0.0,
      rubricNotes: (json['rubric_notes'] ?? json['description'] ?? '') as String,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
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
      id: (json['material_id'] ?? json['id'] ?? '').toString(),
      lessonPlanId: (json['lesson_plan'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '') as String,
      materialType: (json['material_type'] ?? 'DOCUMENT') as String,
      resourceUrl: (json['resource_url'] ?? json['url'] ?? '') as String,
      notes: (json['notes'] ?? json['description'] ?? '') as String,
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
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
    this.description = '',
    this.authorId,
    this.authorName = '',
    this.checkerId,
    this.checkerName = '',
    this.isApproved = false,
    this.isPublic = true,
    this.forkedFromId,
    this.gradeLevels = const [],
    this.flows = const [],
    this.gradings = const [],
    this.materials = const [],
    this.isPendingSync = false,
  });

  final String id; // Stringified server PK or `temp_lp_*`
  final String title;
  final String subject;
  final String description;
  final int? authorId;
  final String authorName;
  final int? checkerId;
  final String checkerName;
  final bool isApproved;
  final bool isPublic;
  final int? forkedFromId;
  final List<LessonGradeLevel> gradeLevels;
  final List<LessonFlow> flows;
  final List<LessonGrading> gradings;
  final List<LessonMaterial> materials;
  final bool isPendingSync;

  int? get serverId => int.tryParse(id);
  bool get isLocalDraft => serverId == null;

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final authorObj = json['author_detail'] ?? json['author'];
    int? aId;
    String aName = (json['author_username'] ?? '') as String;
    if (authorObj is int) {
      aId = authorObj;
    } else if (authorObj is Map<String, dynamic>) {
      aId = (authorObj['id'] ?? authorObj['user_id']) as int?;
      aName = (authorObj['username'] ?? aName) as String;
    }

    final checkerObj = json['checker_detail'] ?? json['checker'];
    int? cId;
    String cName = (json['checker_username'] ?? '') as String;
    if (checkerObj is int) {
      cId = checkerObj;
    } else if (checkerObj is Map<String, dynamic>) {
      cId = (checkerObj['id'] ?? checkerObj['user_id']) as int?;
      cName = (checkerObj['username'] ?? cName) as String;
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

    return LessonPlan(
      id: (json['lp_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '') as String,
      subject: (json['subject'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      authorId: aId,
      authorName: aName,
      checkerId: cId,
      checkerName: cName,
      isApproved: (json['is_approved'] ?? false) as bool,
      isPublic: (json['is_public'] ?? true) as bool,
      forkedFromId: json['forked_from'] as int?,
      gradeLevels: parseList(
        json['lesson_grade_levels'] ?? json['grade_levels'],
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
        json['materials'],
        LessonMaterial.fromJson,
      ),
      isPendingSync: (json['is_pending_sync'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'description': description,
        'author': authorId,
        'author_username': authorName,
        'checker': checkerId,
        'checker_username': checkerName,
        'is_approved': isApproved,
        'is_public': isPublic,
        'forked_from': forkedFromId,
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
    String? description,
    int? authorId,
    String? authorName,
    int? checkerId,
    String? checkerName,
    bool? isApproved,
    bool? isPublic,
    int? forkedFromId,
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
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      checkerId: checkerId ?? this.checkerId,
      checkerName: checkerName ?? this.checkerName,
      isApproved: isApproved ?? this.isApproved,
      isPublic: isPublic ?? this.isPublic,
      forkedFromId: forkedFromId ?? this.forkedFromId,
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
