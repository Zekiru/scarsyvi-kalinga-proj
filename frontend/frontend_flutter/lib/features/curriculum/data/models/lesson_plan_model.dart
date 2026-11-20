import 'dart:convert';
import 'grade_level_model.dart';
import 'json_parsers.dart';
import 'lesson_components_models.dart';

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
    final parsedAuthors = _parseAuthors(json);
    final checkerObj = json['checker_detail'] ?? json['checker'];
    final int? cId = asNullableInt(checkerObj);
    String cName = asString(json['checker_username'] ?? json['checker_name']);
    if (checkerObj is Map<String, dynamic> && cName.isEmpty) {
      cName = asString(checkerObj['username']);
    }

    final demographic = asString(json['suggested_demographic']);
    final desc = asString(json['description'] ?? json['overview']);

    return LessonPlan(
      id: asString(json['lp_id'] ?? json['id'] ?? json['pk']),
      title: asString(json['lp_title'] ?? json['title'] ?? json['name']),
      subject: asString(json['learning_area'] ?? json['subject'] ?? json['subject_area']),
      primaryLanguage: asString(json['primary_language'], 'English'),
      suggestedDemographic: demographic,
      description: desc.isNotEmpty ? desc : demographic,
      authorId: parsedAuthors.primaryId,
      authorName: parsedAuthors.displayNames,
      authorIds: parsedAuthors.ids,
      checkerId: cId,
      checkerName: cName,
      isApproved: asBool(json['is_approved']),
      isPublic: asBool(json['is_public'], true),
      forkedFromId: asNullableInt(json['forked_from']),
      forkCount: asInt(json['fork_count']),
      gradeLevels: parseModelList(
        json['grade_levels'] ?? json['lesson_grade_levels'],
        LessonGradeLevel.fromJson,
      ),
      flows: parseModelList(
        json['lesson_flows'] ?? json['flows'],
        LessonFlow.fromJson,
      ),
      gradings: parseModelList(
        json['lesson_gradings'] ?? json['gradings'],
        LessonGrading.fromJson,
      ),
      materials: parseModelList(
        json['materials'] ?? json['lesson_materials'],
        LessonMaterial.fromJson,
      ),
      isPendingSync: asBool(json['is_pending_sync']),
    );
  }

  static ({int? primaryId, String displayNames, List<int> ids}) _parseAuthors(
    Map<String, dynamic> json,
  ) {
    int? aId;
    String aName = asString(json['author_username'] ?? json['author_name']);
    final ids = <int>[];

    final authorsList = json['authors'];
    if (authorsList is List && authorsList.isNotEmpty) {
      final names = <String>[];
      for (final entry in authorsList) {
        if (entry is Map<String, dynamic>) {
          final acct = entry['account'];
          if (acct is Map<String, dynamic>) {
            final uid = asNullableInt(acct['id'] ?? acct['user_id']);
            if (uid != null) {
              ids.add(uid);
              aId ??= uid;
            }
            final uname = asString(acct['username']);
            if (uname.isNotEmpty) names.add(uname);
          } else {
            final uid = asNullableInt(entry['account'] ?? entry['user_id'] ?? entry['id']);
            if (uid != null) {
              ids.add(uid);
              aId ??= uid;
            }
            final uname = asString(entry['username']);
            if (uname.isNotEmpty) names.add(uname);
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

    return (primaryId: aId, displayNames: aName, ids: ids);
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

  static List<LessonPlan> decodeList(String raw) =>
      parseModelList(jsonDecode(raw), LessonPlan.fromJson);
}
