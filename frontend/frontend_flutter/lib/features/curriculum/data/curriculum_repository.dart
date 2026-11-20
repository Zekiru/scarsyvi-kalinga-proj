import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/sync/id_mapping_store.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'curriculum_cache_store.dart';
import 'curriculum_models.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(
    apiClient: ref.watch(apiClientProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
    cache: CurriculumCacheStore(HiveBoxes.curriculum),
  );
});

class CurriculumRepository {
  CurriculumRepository({
    required this._apiClient,
    required this._syncQueue,
    required this._cache,
  });

  final ApiClient _apiClient;
  final SyncQueueService _syncQueue;
  final CurriculumCacheStore _cache;

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      if (response['results'] is List) return response['results'] as List<dynamic>;
      if (response['data'] is List) return response['data'] as List<dynamic>;
      for (final val in response.values) {
        if (val is List) return val;
      }
    }
    return const [];
  }

  List<GradeLevel> getCachedGradeLevels() => _cache.getGradeLevels();
  List<LessonPlan> getCachedLessonPlans() => _cache.getLessonPlans();

  Future<List<GradeLevel>> fetchGradeLevels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.gradeLevels);
      final levels = parseModelList(_extractList(response), GradeLevel.fromJson);
      await _cache.saveGradeLevels(levels);
      return levels;
    } on ApiException catch (e) {
      final cached = _cache.getGradeLevels();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
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
          parseModelList(_extractList(response), LessonPlan.fromJson);
      final unsyncedLocal =
          _cache.getLessonPlans().where((p) => p.isLocalDraft).toList();
      final merged = [...unsyncedLocal, ...serverPlans];

      await _cache.saveLessonPlans(merged);
      return merged;
    } on ApiException catch (e) {
      final cached = _cache.getLessonPlans();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<LessonPlan> fetchLessonPlanDetail(String id) async {
    final serverId = int.tryParse(id);
    if (serverId == null) {
      final cached = _cache.getLessonPlanDetail(id);
      if (cached != null) return cached;
      throw ApiException(message: 'Local draft lesson plan not found.');
    }

    try {
      final response =
          await _apiClient.get(ApiEndpoints.lessonPlanDetail(serverId));
      var plan = LessonPlan.fromJson(response as Map<String, dynamic>);

      if (plan.flows.isEmpty && plan.gradings.isEmpty && plan.materials.isEmpty) {
        plan = await _hydrateChildrenFromEndpoints(serverId, plan);
      }

      final existing = _cache.getLessonPlanDetail(id);
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

      await _cache.saveDetail(merged);
      return merged;
    } on ApiException catch (e) {
      final cached = _cache.getLessonPlanDetail(id);
      if (e.isOffline && cached != null) return cached;
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<LessonPlan> _hydrateChildrenFromEndpoints(
    int serverId,
    LessonPlan plan,
  ) async {
    final query = {'lesson_plan': serverId};
    final planIdStr = serverId.toString();

    final results = await Future.wait<dynamic>([
      if (plan.gradeLevels.isEmpty)
        _apiClient
            .get(ApiEndpoints.lessonGradeLevels, queryParams: query)
            .catchError((_) => null)
      else
        Future.value(null),
      _apiClient
          .get(ApiEndpoints.lessonFlows, queryParams: query)
          .catchError((_) => null),
      _apiClient
          .get(ApiEndpoints.lessonGradings, queryParams: query)
          .catchError((_) => null),
      _apiClient
          .get(ApiEndpoints.materials, queryParams: query)
          .catchError((_) => null),
    ]);

    bool belongsToPlan(String lpId) => lpId.isEmpty || lpId == planIdStr;

    return plan.copyWith(
      gradeLevels: plan.gradeLevels.isNotEmpty
          ? plan.gradeLevels
          : parseModelList(_extractList(results[0]), LessonGradeLevel.fromJson)
              .where((e) => belongsToPlan(e.lessonPlanId))
              .toList(),
      flows: parseModelList(_extractList(results[1]), LessonFlow.fromJson)
          .where((e) => belongsToPlan(e.lessonPlanId))
          .toList(),
      gradings: parseModelList(_extractList(results[2]), LessonGrading.fromJson)
          .where((e) => belongsToPlan(e.lessonPlanId))
          .toList(),
      materials: parseModelList(_extractList(results[3]), LessonMaterial.fromJson)
          .where((e) => belongsToPlan(e.lessonPlanId))
          .toList(),
    );
  }

  Future<LessonPlan> createLessonPlan({
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    bool isPublic = true,
    int? authorId,
    String authorName = '',
  }) async {
    final payload = {
      'lp_title': title.trim(),
      'learning_area': subject.trim(),
      'primary_language': primaryLanguage.trim(),
      'suggested_demographic': suggestedDemographic.trim(),
      'is_public': isPublic,
    };

    try {
      final response =
          await _apiClient.post(ApiEndpoints.lessonPlans, body: payload);
      final created = LessonPlan.fromJson(response as Map<String, dynamic>);
      await _cache.saveDetail(created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('lp');
      final draft = LessonPlan(
        id: tempId,
        title: title.trim(),
        subject: subject.trim(),
        primaryLanguage: primaryLanguage.trim(),
        suggestedDemographic: suggestedDemographic.trim(),
        description: suggestedDemographic.trim(),
        authorId: authorId,
        authorName: authorName,
        authorIds: authorId != null ? [authorId] : const [],
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
      await _cache.saveDetail(draft);
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
      await _cache.appendChild(lessonPlanId, gradeLevel: created);
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
      await _cache.appendChild(lessonPlanId, gradeLevel: draft);
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
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final payload = <String, dynamic>{
      'lesson_plan': lessonPlanId.startsWith(IdMappingStore.tempPrefix)
          ? lessonPlanId
          : int.parse(lessonPlanId),
      if (lessonGradeLevelId != null)
        'lesson_grade_level': lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix)
            ? lessonGradeLevelId
            : int.parse(lessonGradeLevelId),
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
      await _cache.appendChild(lessonPlanId, flow: created);
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
      await _cache.appendChild(lessonPlanId, flow: draft);
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
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final payload = <String, dynamic>{
      'lesson_plan': lessonPlanId.startsWith(IdMappingStore.tempPrefix)
          ? lessonPlanId
          : int.parse(lessonPlanId),
      if (lessonGradeLevelId != null)
        'lesson_grade_level': lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix)
            ? lessonGradeLevelId
            : int.parse(lessonGradeLevelId),
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
      await _cache.appendChild(lessonPlanId, grading: created);
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
      await _cache.appendChild(lessonPlanId, grading: draft);
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
      await _cache.appendChild(lessonPlanId, material: created);
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
      await _cache.appendChild(lessonPlanId, material: draft);
      return draft;
    }
  }

  Future<LessonPlan> forkLessonPlan(int serverId) async {
    final response =
        await _apiClient.post(ApiEndpoints.lessonPlanFork(serverId));
    final forked = LessonPlan.fromJson(response as Map<String, dynamic>);
    await _cache.saveDetail(forked);
    return forked;
  }

  Future<LessonPlan> setLessonPlanApproval({
    required String lessonPlanId,
    required bool isApproved,
  }) async {
    final endpoint = '/curriculum/lesson-plans/$lessonPlanId/';
    final payload = {'is_approved': isApproved};

    try {
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonPlan.fromJson(response as Map<String, dynamic>);
      await _cache.saveDetail(updated);
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

      final existing = _cache.getLessonPlanDetail(lessonPlanId);
      if (existing != null) {
        final optimistic =
            existing.copyWith(isApproved: isApproved, isPendingSync: true);
        await _cache.saveDetail(optimistic);
        return optimistic;
      }
      rethrow;
    }
  }

  List<String> _collectDependencies(String lessonPlanId, String? lessonGradeLevelId) {
    return [
      if (lessonPlanId.startsWith(IdMappingStore.tempPrefix)) lessonPlanId,
      if (lessonGradeLevelId != null &&
          lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix))
        lessonGradeLevelId,
    ];
  }
}
