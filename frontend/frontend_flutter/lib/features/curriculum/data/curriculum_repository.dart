import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/sync/id_mapping_store.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'curriculum_models.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(
    apiClient: ref.watch(apiClientProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
    cacheBox: HiveBoxes.curriculum,
  );
});

class CurriculumRepository {
  CurriculumRepository({
    required this._apiClient,
    required this._syncQueue,
    required this._cacheBox,
  });

  final ApiClient _apiClient;
  final SyncQueueService _syncQueue;
  final Box<String> _cacheBox;

  static const String _gradeLevelsKey = 'grade_levels';
  static const String _lessonPlansKey = 'lesson_plans';
  static String _lessonDetailKey(String id) => 'lesson_plan_$id';

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
  // READS (Network-first with Hive fallback)
  // ==========================================

  Future<List<GradeLevel>> fetchGradeLevels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.gradeLevels);
      final levels = _parseItems(_extractList(response), GradeLevel.fromJson);

      await _cacheBox.put(
        _gradeLevelsKey,
        jsonEncode(levels.map((e) => e.toJson()).toList()),
      );
      return levels;
    } on ApiException catch (e) {
      final cached = getCachedGradeLevels();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<GradeLevel> getCachedGradeLevels() {
    final raw = _cacheBox.get(_gradeLevelsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return _parseItems(list, GradeLevel.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<List<LessonPlan>> fetchLessonPlans({String? search}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.lessonPlans,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final serverPlans =
          _parseItems(_extractList(response), LessonPlan.fromJson);

      // Preserve any unsynced local draft plans so they don't vanish before replay
      final unsyncedLocal =
          getCachedLessonPlans().where((p) => p.isLocalDraft).toList();
      final merged = [...unsyncedLocal, ...serverPlans];

      await _cacheBox.put(_lessonPlansKey, LessonPlan.encodeList(merged));
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedLessonPlans();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<LessonPlan> getCachedLessonPlans() {
    final raw = _cacheBox.get(_lessonPlansKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return LessonPlan.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<LessonPlan> fetchLessonPlanDetail(String id) async {
    final serverId = int.tryParse(id);
    if (serverId == null) {
      // Offline draft (`temp_lp_*`) — read directly from Hive cache
      final cached = getCachedLessonPlanDetail(id);
      if (cached != null) return cached;
      throw ApiException(message: 'Local draft lesson plan not found.');
    }

    try {
      final response =
          await _apiClient.get(ApiEndpoints.lessonPlanDetail(serverId));
      final plan = LessonPlan.fromJson(response as Map<String, dynamic>);

      // Merge any unsynced local children onto the fresh server plan
      final existing = getCachedLessonPlanDetail(id);
      final merged = existing == null
          ? plan
          : plan.copyWith(
              gradeLevels: [
                ...plan.gradeLevels,
                ...existing.gradeLevels.where((g) => g.isPendingSync),
              ],
              flows: [
                ...plan.flows,
                ...existing.flows.where((f) => f.isPendingSync),
              ],
              gradings: [
                ...plan.gradings,
                ...existing.gradings.where((g) => g.isPendingSync),
              ],
              materials: [
                ...plan.materials,
                ...existing.materials.where((m) => m.isPendingSync),
              ],
            );

      await _saveDetailCache(merged);
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedLessonPlanDetail(id);
      if (e.isOffline && cached != null) return cached;
      if (cached != null) return cached;
      rethrow;
    }
  }

  LessonPlan? getCachedLessonPlanDetail(String id) {
    final raw = _cacheBox.get(_lessonDetailKey(id));
    if (raw != null && raw.isNotEmpty) {
      try {
        return LessonPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return getCachedLessonPlans().where((p) => p.id == id).firstOrNull;
  }

  Future<void> _saveDetailCache(LessonPlan plan) async {
    await _cacheBox.put(_lessonDetailKey(plan.id), jsonEncode(plan.toJson()));
    final currentList = getCachedLessonPlans();
    final idx = currentList.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      currentList[idx] = plan;
    } else {
      currentList.insert(0, plan);
    }
    await _cacheBox.put(_lessonPlansKey, LessonPlan.encodeList(currentList));
  }

  // ==========================================
  // MUTATIONS (Online-first with Offline Queue)
  // ==========================================

  Future<LessonPlan> createLessonPlan({
    required String title,
    required String subject,
    required String description,
    bool isPublic = true,
    int? authorId,
    String authorName = '',
  }) async {
    final payload = {
      'title': title.trim(),
      'subject': subject.trim(),
      'description': description.trim(),
      'is_public': isPublic,
    };

    try {
      final response =
          await _apiClient.post(ApiEndpoints.lessonPlans, body: payload);
      final created = LessonPlan.fromJson(response as Map<String, dynamic>);
      await _saveDetailCache(created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('lp');
      final draft = LessonPlan(
        id: tempId,
        title: title.trim(),
        subject: subject.trim(),
        description: description.trim(),
        authorId: authorId,
        authorName: authorName,
        isPublic: isPublic,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_plan',
        method: 'POST',
        endpoint: ApiEndpoints.lessonPlans,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'lp_id',
      );
      await _saveDetailCache(draft);
      return draft;
    }
  }

  Future<LessonGradeLevel> addLessonGradeLevel({
    required String lessonPlanId,
    required int gradeLevelId,
    required String gradeLevelName,
    String specificObjectives = '',
  }) async {
    final isParentTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final payload = <String, dynamic>{
      'lesson_plan': isParentTemp ? lessonPlanId : int.parse(lessonPlanId),
      'grade_level': gradeLevelId,
      'specific_objectives': specificObjectives.trim(),
    };

    try {
      if (isParentTemp) {
        throw ApiException(message: 'Parent plan is offline draft', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonGradeLevels, body: payload);
      final created =
          LessonGradeLevel.fromJson(response as Map<String, dynamic>);
      await _appendChildToPlan(lessonPlanId, gradeLevel: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('lgl');
      final draft = LessonGradeLevel(
        id: tempId,
        lessonPlanId: lessonPlanId,
        gradeLevelId: gradeLevelId,
        gradeLevelName: gradeLevelName,
        specificObjectives: specificObjectives.trim(),
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_grade_level',
        method: 'POST',
        endpoint: ApiEndpoints.lessonGradeLevels,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'id',
        dependsOnTempIds: isParentTemp ? [lessonPlanId] : const [],
      );
      await _appendChildToPlan(lessonPlanId, gradeLevel: draft);
      return draft;
    }
  }

  Future<LessonFlow> addLessonFlow({
    required String lessonPlanId,
    String? lessonGradeLevelId,
    required int stepOrder,
    required String phaseName,
    required String activityDescription,
    int durationMinutes = 10,
  }) async {
    final deps = <String>[];
    final isParentTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    if (isParentTemp) deps.add(lessonPlanId);

    final isLglTemp = lessonGradeLevelId != null &&
        lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);
    if (isLglTemp) deps.add(lessonGradeLevelId);

    final payload = <String, dynamic>{
      'lesson_plan': isParentTemp ? lessonPlanId : int.parse(lessonPlanId),
      if (lessonGradeLevelId != null)
        'lesson_grade_level':
            isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'step_order': stepOrder,
      'phase_name': phaseName.trim(),
      'activity_description': activityDescription.trim(),
      'duration_minutes': durationMinutes,
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonFlows, body: payload);
      final created = LessonFlow.fromJson(response as Map<String, dynamic>);
      await _appendChildToPlan(lessonPlanId, flow: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonFlow(
        id: IdMappingStore.generateTempId('flow'),
        lessonPlanId: lessonPlanId,
        lessonGradeLevelId: lessonGradeLevelId,
        stepOrder: stepOrder,
        phaseName: phaseName.trim(),
        activityDescription: activityDescription.trim(),
        durationMinutes: durationMinutes,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_flow',
        method: 'POST',
        endpoint: ApiEndpoints.lessonFlows,
        payload: payload,
        dependsOnTempIds: deps,
      );
      await _appendChildToPlan(lessonPlanId, flow: draft);
      return draft;
    }
  }

  Future<LessonGrading> addLessonGrading({
    required String lessonPlanId,
    String? lessonGradeLevelId,
    required String criteriaName,
    required double weightPercentage,
    String rubricNotes = '',
  }) async {
    final deps = <String>[];
    final isParentTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    if (isParentTemp) deps.add(lessonPlanId);

    final isLglTemp = lessonGradeLevelId != null &&
        lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);
    if (isLglTemp) deps.add(lessonGradeLevelId);

    final payload = <String, dynamic>{
      'lesson_plan': isParentTemp ? lessonPlanId : int.parse(lessonPlanId),
      if (lessonGradeLevelId != null)
        'lesson_grade_level':
            isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'criteria_name': criteriaName.trim(),
      'weight_percentage': weightPercentage,
      'rubric_notes': rubricNotes.trim(),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonGradings, body: payload);
      final created = LessonGrading.fromJson(response as Map<String, dynamic>);
      await _appendChildToPlan(lessonPlanId, grading: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonGrading(
        id: IdMappingStore.generateTempId('grad'),
        lessonPlanId: lessonPlanId,
        lessonGradeLevelId: lessonGradeLevelId,
        criteriaName: criteriaName.trim(),
        weightPercentage: weightPercentage,
        rubricNotes: rubricNotes.trim(),
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_grading',
        method: 'POST',
        endpoint: ApiEndpoints.lessonGradings,
        payload: payload,
        dependsOnTempIds: deps,
      );
      await _appendChildToPlan(lessonPlanId, grading: draft);
      return draft;
    }
  }

  Future<LessonMaterial> addMaterial({
    required String lessonPlanId,
    required String title,
    String materialType = 'DOCUMENT',
    String resourceUrl = '',
    String notes = '',
  }) async {
    final isParentTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final payload = <String, dynamic>{
      'lesson_plan': isParentTemp ? lessonPlanId : int.parse(lessonPlanId),
      'title': title.trim(),
      'material_type': materialType,
      'resource_url': resourceUrl.trim(),
      'notes': notes.trim(),
    };

    try {
      if (isParentTemp) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.materials, body: payload);
      final created = LessonMaterial.fromJson(response as Map<String, dynamic>);
      await _appendChildToPlan(lessonPlanId, material: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonMaterial(
        id: IdMappingStore.generateTempId('mat'),
        lessonPlanId: lessonPlanId,
        title: title.trim(),
        materialType: materialType,
        resourceUrl: resourceUrl.trim(),
        notes: notes.trim(),
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'material',
        method: 'POST',
        endpoint: ApiEndpoints.materials,
        payload: payload,
        dependsOnTempIds: isParentTemp ? [lessonPlanId] : const [],
      );
      await _appendChildToPlan(lessonPlanId, material: draft);
      return draft;
    }
  }

  /// Forks an existing server lesson plan (`POST /curriculum/lesson-plans/{id}/fork/`).
  Future<LessonPlan> forkLessonPlan(int serverId) async {
    final response =
        await _apiClient.post(ApiEndpoints.lessonPlanFork(serverId));
    final forked = LessonPlan.fromJson(response as Map<String, dynamic>);
    await _saveDetailCache(forked);
    return forked;
  }

  /// Checker or Admin approves/unapproves a lesson plan (`PATCH /curriculum/lesson-plans/{id}/`).
  Future<LessonPlan> setLessonPlanApproval({
    required String lessonPlanId,
    required bool isApproved,
  }) async {
    final endpoint = '/curriculum/lesson-plans/$lessonPlanId/';
    final payload = {'is_approved': isApproved};

    try {
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonPlan.fromJson(response as Map<String, dynamic>);
      await _saveDetailCache(updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_plan_approval',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: lessonPlanId.startsWith(IdMappingStore.tempPrefix)
            ? [lessonPlanId]
            : const [],
      );

      final existing = getCachedLessonPlanDetail(lessonPlanId);
      if (existing != null) {
        final optimistic =
            existing.copyWith(isApproved: isApproved, isPendingSync: true);
        await _saveDetailCache(optimistic);
        return optimistic;
      }
      rethrow;
    }
  }

  Future<void> _appendChildToPlan(
    String lessonPlanId, {
    LessonGradeLevel? gradeLevel,
    LessonFlow? flow,
    LessonGrading? grading,
    LessonMaterial? material,
  }) async {
    final existing = getCachedLessonPlanDetail(lessonPlanId);
    if (existing == null) return;

    final updated = existing.copyWith(
      gradeLevels: gradeLevel != null
          ? [...existing.gradeLevels, gradeLevel]
          : existing.gradeLevels,
      flows: flow != null ? [...existing.flows, flow] : existing.flows,
      gradings:
          grading != null ? [...existing.gradings, grading] : existing.gradings,
      materials: material != null
          ? [...existing.materials, material]
          : existing.materials,
    );
    await _saveDetailCache(updated);
  }
}
