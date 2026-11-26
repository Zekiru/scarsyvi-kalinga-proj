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

  static const String _lessonGradeMaterialsEndpoint =
      '/curriculum/lesson-grade-materials/';

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map) {
      if (response['results'] is List) return response['results'] as List<dynamic>;
      if (response['data'] is List) return response['data'] as List<dynamic>;
      for (final val in response.values) {
        if (val is List) return val;
      }
    }
    return const [];
  }

  Future<List<dynamic>> _fetchAllItems(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    final items = <dynamic>[];
    String? nextUrl = endpoint;
    Map<String, dynamic>? currentParams = queryParams;

    while (nextUrl != null && nextUrl.isNotEmpty) {
      final response = await _apiClient.get(nextUrl, queryParams: currentParams);
      items.addAll(_extractList(response));

      if (response is Map && response['next'] is String) {
        final rawNext = response['next'] as String;
        final apiIdx = rawNext.indexOf('/api/v1/');
        nextUrl = apiIdx >= 0 ? rawNext.substring(apiIdx + 7) : rawNext;
        currentParams = null;
      } else {
        nextUrl = null;
      }
    }
    return items;
  }

  List<GradeLevel> getCachedGradeLevels() => _cache.getGradeLevels();
  List<LessonPlan> getCachedLessonPlans() => _cache.getLessonPlans();
  Future<void> saveCachedLessonPlan(LessonPlan plan) => _cache.saveDetail(plan);

  LessonPlan _preserveResolvedAuthors(LessonPlan incoming, LessonPlan? previous) {
    if (previous == null) return incoming;
    final hasResolvedIncoming = incoming.authorEntries.any(
      (e) => e.username.trim().isNotEmpty || e.fullName.trim().isNotEmpty,
    );
    if (hasResolvedIncoming) return incoming;

    final hasResolvedPrevious = previous.authorEntries.any(
      (e) => e.username.trim().isNotEmpty || e.fullName.trim().isNotEmpty,
    );
    if (!hasResolvedPrevious) return incoming;

    return incoming.copyWith(
      authorId: incoming.authorId ?? previous.authorId,
      authorName: previous.authorName,
      authorIds: incoming.authorIds.isNotEmpty
          ? incoming.authorIds
          : previous.authorIds,
      authorEntries: previous.authorEntries,
    );
  }

  Future<List<GradeLevel>> fetchGradeLevels() async {
    try {
      final raw = await _fetchAllItems(ApiEndpoints.gradeLevels);
      final levels = parseModelList(raw, GradeLevel.fromJson);
      await _cache.saveGradeLevels(levels);
      return levels;
    } catch (e) {
      final cached = _cache.getGradeLevels();
      if (cached.isNotEmpty) return cached;
      if (e is ApiException && e.isOffline) return const [];
      rethrow;
    }
  }

  Future<List<LessonPlan>> fetchLessonPlans({String? search}) async {
    try {
      final raw = await _fetchAllItems(
        ApiEndpoints.lessonPlans,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final cachedPlans = _cache.getLessonPlans();
      final cachedById = {for (final p in cachedPlans) p.id: p};

      final serverPlans = parseModelList(raw, LessonPlan.fromJson)
          .map((plan) => _preserveResolvedAuthors(plan, cachedById[plan.id]))
          .toList();
      final unsyncedLocal = _syncQueue.hasActiveOperations
          ? cachedPlans.where((p) => p.isLocalDraft).toList()
          : const <LessonPlan>[];
      final merged = [...unsyncedLocal, ...serverPlans];

      final serverPlanIds = serverPlans.map((p) => p.id).toSet();
      for (final old in cachedPlans) {
        if (!old.isLocalDraft && !serverPlanIds.contains(old.id)) {
          await _cache.removeLessonPlan(old.id);
        }
      }

      await _cache.saveLessonPlans(merged);
      return merged;
    } catch (e) {
      final cached = _cache.getLessonPlans();
      if (cached.isNotEmpty) return cached;
      if (e is ApiException && e.isOffline) return const [];
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
      var plan = LessonPlan.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      final needsGradeLevelsHydration = plan.gradeLevels.isEmpty ||
          plan.gradeLevels.any((g) => g.id.isEmpty) ||
          !plan.gradeLevels.any((g) => g.hasDetailedStandards);

      if (needsGradeLevelsHydration ||
          plan.flows.isEmpty ||
          plan.gradings.isEmpty ||
          plan.materials.isEmpty) {
        plan = await _hydrateChildrenFromEndpoints(
          serverId,
          plan,
          fetchGradeLevels: needsGradeLevelsHydration,
        );
      }

      final existing = _cache.getLessonPlanDetail(id);
      plan = _preserveResolvedAuthors(plan, existing);

      final hasQueue = _syncQueue.hasActiveOperations;
      final merged = existing == null
          ? plan
          : plan.copyWith(
              gradeLevels: [
                ...plan.gradeLevels,
                if (hasQueue)
                  ...existing.gradeLevels.where((g) => g.isPendingSync),
              ],
              flows: [
                ...plan.flows,
                if (hasQueue) ...existing.flows.where((f) => f.isPendingSync),
              ],
              gradings: [
                ...plan.gradings,
                if (hasQueue)
                  ...existing.gradings.where((g) => g.isPendingSync),
              ],
              materials: [
                ...plan.materials,
                if (hasQueue)
                  ...existing.materials.where((m) => m.isPendingSync),
              ],
            );

      await _cache.saveDetail(merged);
      return merged;
    } catch (_) {
      final cached = _cache.getLessonPlanDetail(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<LessonPlan> _hydrateChildrenFromEndpoints(
    int serverId,
    LessonPlan plan, {
    required bool fetchGradeLevels,
  }) async {
    final planIdStr = serverId.toString();

    var resolvedGradeLevels = plan.gradeLevels;
    if (fetchGradeLevels) {
      final rawLgl = await _fetchAllItems(
        ApiEndpoints.lessonGradeLevels,
        queryParams: {'lp': serverId},
      ).catchError((_) => <dynamic>[]);

      final fetchedLgl = parseModelList(rawLgl, LessonGradeLevel.fromJson)
          .where((e) => e.lessonPlanId.isEmpty || e.lessonPlanId == planIdStr)
          .toList();

      if (fetchedLgl.isNotEmpty) {
        resolvedGradeLevels = fetchedLgl;
      }
    }

    final validLglIds = resolvedGradeLevels
        .map((g) => g.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final lglNameMap = {
      for (final g in resolvedGradeLevels)
        if (g.id.isNotEmpty && g.gradeLevelName.isNotEmpty) g.id: g.gradeLevelName,
    };

    final nestedFlows = resolvedGradeLevels.expand((g) => g.flows).toList();
    final nestedGradings =
        resolvedGradeLevels.expand((g) => g.gradingTasks).toList();
    final nestedMaterials =
        resolvedGradeLevels.expand((g) => g.materials).toList();

    final results = await Future.wait<List<dynamic>>([
      if (plan.flows.isEmpty && nestedFlows.isEmpty)
        _fetchAllItems(ApiEndpoints.lessonFlows).catchError((_) => <dynamic>[])
      else
        Future.value(const <dynamic>[]),
      if (plan.gradings.isEmpty && nestedGradings.isEmpty)
        _fetchAllItems(ApiEndpoints.lessonGradings)
            .catchError((_) => <dynamic>[])
      else
        Future.value(const <dynamic>[]),
      if (plan.materials.isEmpty && nestedMaterials.isEmpty)
        _fetchAllItems(_lessonGradeMaterialsEndpoint)
            .catchError((_) => <dynamic>[])
      else
        Future.value(const <dynamic>[]),
    ]);

    bool belongsToPlan(String lpId, String? lglId) {
      if (lglId != null && lglId.isNotEmpty && validLglIds.contains(lglId)) {
        return true;
      }
      if (lpId.isNotEmpty && lpId == planIdStr) return true;
      return false;
    }

    final resolvedFlows = plan.flows.isNotEmpty
        ? plan.flows
        : nestedFlows.isNotEmpty
            ? nestedFlows
            : parseModelList(results[0], LessonFlow.fromJson)
                .where((e) => belongsToPlan(e.lessonPlanId, e.lessonGradeLevelId))
                .map((e) => e.gradeLevelName.isEmpty &&
                        lglNameMap.containsKey(e.lessonGradeLevelId)
                    ? e.copyWith(gradeLevelName: lglNameMap[e.lessonGradeLevelId])
                    : e)
                .toList();

    final resolvedGradings = plan.gradings.isNotEmpty
        ? plan.gradings
        : nestedGradings.isNotEmpty
            ? nestedGradings
            : parseModelList(results[1], LessonGrading.fromJson)
                .where((e) => belongsToPlan(e.lessonPlanId, e.lessonGradeLevelId))
                .map((e) => e.gradeLevelName.isEmpty &&
                        lglNameMap.containsKey(e.lessonGradeLevelId)
                    ? e.copyWith(gradeLevelName: lglNameMap[e.lessonGradeLevelId])
                    : e)
                .toList();

    final resolvedMaterials = plan.materials.isNotEmpty
        ? plan.materials
        : nestedMaterials.isNotEmpty
            ? nestedMaterials
            : parseModelList(results[2], LessonMaterial.fromJson)
                .where((e) => belongsToPlan(e.lessonPlanId, e.lessonGradeLevelId))
                .map((e) => e.gradeLevelName.isEmpty &&
                        lglNameMap.containsKey(e.lessonGradeLevelId)
                    ? e.copyWith(gradeLevelName: lglNameMap[e.lessonGradeLevelId])
                    : e)
                .toList();

    final enrichedGradeLevels = resolvedGradeLevels.map((gl) {
      final glFlows = gl.flows.isNotEmpty
          ? gl.flows
          : resolvedFlows.where((f) => f.lessonGradeLevelId == gl.id).toList();
      final glGradings = gl.gradingTasks.isNotEmpty
          ? gl.gradingTasks
          : resolvedGradings
              .where((g) => g.lessonGradeLevelId == gl.id)
              .toList();
      final glMaterials = gl.materials.isNotEmpty
          ? gl.materials
          : resolvedMaterials
              .where((m) => m.lessonGradeLevelId == gl.id)
              .toList();
      return gl.copyWith(
        flows: glFlows,
        gradingTasks: glGradings,
        materials: glMaterials,
      );
    }).toList();

    return plan.copyWith(
      gradeLevels: enrichedGradeLevels,
      flows: resolvedFlows,
      gradings: resolvedGradings,
      materials: resolvedMaterials,
    );
  }

  // ---------------- LESSON PLAN CRUD ----------------

  Future<LessonPlan> createLessonPlan({
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    String multigradeModel = '',
    String sharedSubTheme = '',
    bool isPublic = true,
    int? authorId,
    String authorName = '',
  }) async {
    final payload = <String, dynamic>{
      'lp_title': title.trim(),
      'learning_area': subject.trim(),
      'primary_language': primaryLanguage.trim(),
      'suggested_demographic': suggestedDemographic.trim(),
      if (multigradeModel.trim().isNotEmpty)
        'learning_model_description': multigradeModel.trim(),
      if (sharedSubTheme.trim().isNotEmpty)
        'intentions_description': sharedSubTheme.trim(),
    };

    try {
      final response =
          await _apiClient.post(ApiEndpoints.lessonPlans, body: payload);
      var created = LessonPlan.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      if (created.authorEntries.isEmpty &&
          authorId != null &&
          authorName.trim().isNotEmpty) {
        created = created.copyWith(
          authorId: created.authorId ?? authorId,
          authorName: authorName.trim(),
          authorIds:
              created.authorIds.isEmpty ? [authorId] : created.authorIds,
          authorEntries: [
            LessonAuthorEntry(
              userId: authorId,
              username: authorName.trim(),
              authorRole: 'Primary Author',
            ),
          ],
        );
      }
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
        learningModelDescription: multigradeModel.trim(),
        intentionsDescription: sharedSubTheme.trim(),
        description: suggestedDemographic.trim(),
        authorId: authorId,
        authorName: authorName,
        authorIds: authorId != null ? [authorId] : const [],
        authorEntries: authorId != null
            ? [
                LessonAuthorEntry(
                  userId: authorId,
                  username: authorName,
                  authorRole: 'Primary Author',
                ),
              ]
            : const [],
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

  Future<LessonPlan> updateLessonPlan({
    required String lessonPlanId,
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    String multigradeModel = '',
    String sharedSubTheme = '',
    String learnerContext = '',
    String reflectionQuestions = '',
    String notesForNextSession = '',
    bool isPublic = true,
  }) async {
    final payload = <String, dynamic>{
      'lp_title': title.trim(),
      'learning_area': subject.trim(),
      'primary_language': primaryLanguage.trim(),
      'suggested_demographic': suggestedDemographic.trim(),
      'learning_model_description': multigradeModel.trim(),
      'intentions_description': sharedSubTheme.trim(),
      'notes': notesForNextSession.trim(),
    };

    final isTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-plans/$lessonPlanId/';

    try {
      if (isTemp) {
        throw ApiException(message: 'Plan is local draft', isOffline: true);
      }
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonPlan.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      final existing = _cache.getLessonPlanDetail(lessonPlanId);
      final merged = existing == null
          ? updated
          : updated.copyWith(
              authorId: updated.authorId ?? existing.authorId,
              authorName: updated.authorName.isNotEmpty
                  ? updated.authorName
                  : existing.authorName,
              authorIds: updated.authorIds.isNotEmpty
                  ? updated.authorIds
                  : existing.authorIds,
              gradeLevels: updated.gradeLevels.isNotEmpty
                  ? updated.gradeLevels
                  : existing.gradeLevels,
              flows: updated.flows.isNotEmpty ? updated.flows : existing.flows,
              gradings: updated.gradings.isNotEmpty
                  ? updated.gradings
                  : existing.gradings,
              materials: updated.materials.isNotEmpty
                  ? updated.materials
                  : existing.materials,
              authorEntries: updated.authorEntries.isNotEmpty
                  ? updated.authorEntries
                  : existing.authorEntries,
              checkerEntries: updated.checkerEntries.isNotEmpty
                  ? updated.checkerEntries
                  : existing.checkerEntries,
            );

      await _cache.saveDetail(merged);
      return merged;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_plan_update',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: isTemp ? [lessonPlanId] : const [],
      );

      final existing = _cache.getLessonPlanDetail(lessonPlanId);
      if (existing != null) {
        final optimistic = existing.copyWith(
          title: title.trim(),
          subject: subject.trim(),
          primaryLanguage: primaryLanguage.trim(),
          suggestedDemographic: suggestedDemographic.trim(),
          learningModelDescription: multigradeModel.trim(),
          intentionsDescription: sharedSubTheme.trim(),
          notes: notesForNextSession.trim(),
          isPublic: isPublic,
          isPendingSync: true,
        );
        await _cache.saveDetail(optimistic);
        return optimistic;
      }
      rethrow;
    }
  }

  Future<void> deleteLessonPlan(String lessonPlanId) async {
    final isTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-plans/$lessonPlanId/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _cache.removeLessonPlan(lessonPlanId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_plan_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [lessonPlanId] : const [],
      );
      await _cache.removeLessonPlan(lessonPlanId);
    }
  }

  // ---------------- LESSON GRADE LEVEL CRUD ----------------

  Future<LessonGradeLevel> addLessonGradeLevel({
    required String lessonPlanId,
    required int gradeLevelId,
    required String gradeLevelName,
    String contentStandard = '',
    String performanceStandard = '',
    String learningCompetencies = '',
    String specificObjectives = '',
    String learnerContext = '',
    String reflectionQuestions = '',
    String remediation = '',
    String enrichment = '',
  }) async {
    final isParentTemp = lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final lpVal = isParentTemp ? lessonPlanId : int.parse(lessonPlanId);

    final payload = <String, dynamic>{
      'lp': lpVal,
      'gl': gradeLevelId,
      if (contentStandard.trim().isNotEmpty)
        'i_content_standard': contentStandard.trim(),
      if (performanceStandard.trim().isNotEmpty)
        'i_performance_standard': performanceStandard.trim(),
      if (learningCompetencies.trim().isNotEmpty)
        'i_competencies_codes': learningCompetencies.trim(),
      if (specificObjectives.trim().isNotEmpty)
        'i_objectives': specificObjectives.trim(),
      if (learnerContext.trim().isNotEmpty) 'l_context': learnerContext.trim(),
      if (reflectionQuestions.trim().isNotEmpty)
        'w_reflection_questions': reflectionQuestions.trim(),
      if (remediation.trim().isNotEmpty) 're_remediation': remediation.trim(),
      if (enrichment.trim().isNotEmpty) 're_enrichment': enrichment.trim(),
    };

    try {
      if (isParentTemp) {
        throw ApiException(message: 'Parent plan is offline draft', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonGradeLevels, body: payload);
      final created = LessonGradeLevel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
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
        contentStandard: contentStandard.trim(),
        performanceStandard: performanceStandard.trim(),
        learningCompetencies: learningCompetencies.trim(),
        learningObjectives: specificObjectives.trim(),
        learnerContext: learnerContext.trim(),
        reflectionQuestions: reflectionQuestions.trim(),
        remediation: remediation.trim(),
        enrichment: enrichment.trim(),
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

  Future<LessonGradeLevel> updateLessonGradeLevel({
    required String lessonPlanId,
    required LessonGradeLevel existing,
    required int gradeLevelId,
    required String gradeLevelName,
    String contentStandard = '',
    String performanceStandard = '',
    String learningCompetencies = '',
    String specificObjectives = '',
    String learnerContext = '',
    String reflectionQuestions = '',
    String remediation = '',
    String enrichment = '',
  }) async {
    final isTemp = existing.id.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-grade-levels/${existing.id}/';

    final payload = <String, dynamic>{
      'gl': gradeLevelId,
      'i_content_standard': contentStandard.trim(),
      'i_performance_standard': performanceStandard.trim(),
      'i_competencies_codes': learningCompetencies.trim(),
      'i_objectives': specificObjectives.trim(),
      'l_context': learnerContext.trim(),
      'w_reflection_questions': reflectionQuestions.trim(),
      're_remediation': remediation.trim(),
      're_enrichment': enrichment.trim(),
    };

    try {
      if (isTemp) {
        throw ApiException(message: 'Record is local draft', isOffline: true);
      }
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonGradeLevel.fromJson(
        Map<String, dynamic>.from(response as Map),
      ).copyWith(
        flows: existing.flows,
        gradingTasks: existing.gradingTasks,
        materials: existing.materials,
      );
      await _cache.replaceChild(lessonPlanId, gradeLevel: updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final optimistic = existing.copyWith(
        gradeLevelId: gradeLevelId,
        gradeLevelName: gradeLevelName,
        contentStandard: contentStandard.trim(),
        performanceStandard: performanceStandard.trim(),
        learningCompetencies: learningCompetencies.trim(),
        learningObjectives: specificObjectives.trim(),
        learnerContext: learnerContext.trim(),
        reflectionQuestions: reflectionQuestions.trim(),
        remediation: remediation.trim(),
        enrichment: enrichment.trim(),
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_grade_level_update',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: isTemp ? [existing.id] : const [],
      );
      await _cache.replaceChild(lessonPlanId, gradeLevel: optimistic);
      return optimistic;
    }
  }

  Future<void> deleteLessonGradeLevel({
    required String lessonPlanId,
    required String lessonGradeLevelId,
  }) async {
    final isTemp = lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-grade-levels/$lessonGradeLevelId/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _cache.removeChild(lessonPlanId, gradeLevelId: lessonGradeLevelId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_grade_level_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [lessonGradeLevelId] : const [],
      );
      await _cache.removeChild(lessonPlanId, gradeLevelId: lessonGradeLevelId);
    }
  }

  // ---------------- LESSON FLOW CRUD ----------------

  Future<LessonFlow> addLessonFlow({
    required String lessonPlanId,
    required String lessonGradeLevelId,
    String gradeLevelName = '',
    required int stepOrder,
    required String stage,
    required String description,
    int timeMinutes = 10,
  }) async {
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final isLglTemp = lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);

    final payload = <String, dynamic>{
      'lesson_grade_level':
          isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'time_minutes': timeMinutes,
      'stage': stage.trim(),
      'description': description.trim(),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonFlows, body: payload);
      final created = LessonFlow.fromJson(
        Map<String, dynamic>.from(response as Map),
      ).copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.appendChild(lessonPlanId, flow: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('flow');
      final draft = LessonFlow(
        id: tempId,
        lessonPlanId: lessonPlanId,
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        stepOrder: stepOrder,
        stage: stage.trim(),
        description: description.trim(),
        timeMinutes: timeMinutes,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_flow',
        method: 'POST',
        endpoint: ApiEndpoints.lessonFlows,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'id',
        dependsOnTempIds: deps,
      );
      await _cache.appendChild(lessonPlanId, flow: draft);
      return draft;
    }
  }

  Future<LessonFlow> updateLessonFlow({
    required String lessonPlanId,
    required LessonFlow existing,
    required String lessonGradeLevelId,
    String gradeLevelName = '',
    required String stage,
    required String description,
    int timeMinutes = 10,
  }) async {
    final isTemp = existing.id.startsWith(IdMappingStore.tempPrefix);
    final isLglTemp = lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-flows/${existing.id}/';

    final payload = <String, dynamic>{
      'lesson_grade_level':
          isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'time_minutes': timeMinutes,
      'stage': stage.trim(),
      'description': description.trim(),
    };

    try {
      if (isTemp || isLglTemp) {
        throw ApiException(message: 'Record is local draft', isOffline: true);
      }
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonFlow.fromJson(
        Map<String, dynamic>.from(response as Map),
      ).copyWith(
        lessonPlanId: lessonPlanId,
        gradeLevelName: gradeLevelName,
        stepOrder: existing.stepOrder,
      );
      await _cache.replaceChild(lessonPlanId, flow: updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final optimistic = existing.copyWith(
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        stage: stage.trim(),
        description: description.trim(),
        timeMinutes: timeMinutes,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_flow_update',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: [
          if (isTemp) existing.id,
          if (isLglTemp) lessonGradeLevelId,
        ],
      );
      await _cache.replaceChild(lessonPlanId, flow: optimistic);
      return optimistic;
    }
  }

  Future<void> deleteLessonFlow({
    required String lessonPlanId,
    required String flowId,
  }) async {
    final isTemp = flowId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-flows/$flowId/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _cache.removeChild(lessonPlanId, flowId: flowId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_flow_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [flowId] : const [],
      );
      await _cache.removeChild(lessonPlanId, flowId: flowId);
    }
  }

  // ---------------- LESSON GRADING CRUD ----------------

  Future<LessonGrading> addLessonGrading({
    required String lessonPlanId,
    required String lessonGradeLevelId,
    String gradeLevelName = '',
    required String taskName,
    String taskDescription = '',
    required double gradeWeight,
    int maxScore = 10,
  }) async {
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final isLglTemp = lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);

    final payload = <String, dynamic>{
      'lesson_grade_level':
          isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'task_name': taskName.trim(),
      'task_description': taskDescription.trim(),
      'grade_weight': gradeWeight.toStringAsFixed(2),
      'max_score': maxScore,
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.lessonGradings, body: payload);
      final created = LessonGrading.fromJson(
        Map<String, dynamic>.from(response as Map),
      ).copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.appendChild(lessonPlanId, grading: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('grad');
      final draft = LessonGrading(
        id: tempId,
        lessonPlanId: lessonPlanId,
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        taskName: taskName.trim(),
        taskDescription: taskDescription.trim(),
        gradeWeight: gradeWeight,
        maxScore: maxScore,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_grading',
        method: 'POST',
        endpoint: ApiEndpoints.lessonGradings,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'id',
        dependsOnTempIds: deps,
      );
      await _cache.appendChild(lessonPlanId, grading: draft);
      return draft;
    }
  }

  Future<LessonGrading> updateLessonGrading({
    required String lessonPlanId,
    required LessonGrading existing,
    required String lessonGradeLevelId,
    String gradeLevelName = '',
    required String taskName,
    String taskDescription = '',
    required double gradeWeight,
    int maxScore = 10,
  }) async {
    final isTemp = existing.id.startsWith(IdMappingStore.tempPrefix);
    final isLglTemp = lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-gradings/${existing.id}/';

    final payload = <String, dynamic>{
      'lesson_grade_level':
          isLglTemp ? lessonGradeLevelId : int.parse(lessonGradeLevelId),
      'task_name': taskName.trim(),
      'task_description': taskDescription.trim(),
      'grade_weight': gradeWeight.toStringAsFixed(2),
      'max_score': maxScore,
    };

    try {
      if (isTemp || isLglTemp) {
        throw ApiException(message: 'Record is local draft', isOffline: true);
      }
      final response = await _apiClient.patch(endpoint, body: payload);
      final updated = LessonGrading.fromJson(
        Map<String, dynamic>.from(response as Map),
      ).copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.replaceChild(lessonPlanId, grading: updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final optimistic = existing.copyWith(
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        taskName: taskName.trim(),
        taskDescription: taskDescription.trim(),
        gradeWeight: gradeWeight,
        maxScore: maxScore,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'lesson_grading_update',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: [
          if (isTemp) existing.id,
          if (isLglTemp) lessonGradeLevelId,
        ],
      );
      await _cache.replaceChild(lessonPlanId, grading: optimistic);
      return optimistic;
    }
  }

  Future<void> deleteLessonGrading({
    required String lessonPlanId,
    required String gradingId,
  }) async {
    final isTemp = gradingId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/curriculum/lesson-gradings/$gradingId/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _cache.removeChild(lessonPlanId, gradingId: gradingId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'lesson_grading_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [gradingId] : const [],
      );
      await _cache.removeChild(lessonPlanId, gradingId: gradingId);
    }
  }

  // ---------------- LESSON MATERIAL CRUD ----------------

  Future<LessonMaterial> addMaterial({
    required String lessonPlanId,
    String? lessonGradeLevelId,
    String gradeLevelName = '',
    required String title,
    String materialType = 'PDF',
    String resourceUrl = '',
    String notes = '',
  }) async {
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final isLglTemp = lessonGradeLevelId != null &&
        lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);

    final materialPayload = <String, dynamic>{
      'file_name': title.trim(),
      'file_url': resourceUrl.trim().isNotEmpty
          ? resourceUrl.trim()
          : 'https://kalinga.local/materials/${Uri.encodeComponent(title.trim())}',
      'file_type': materialType,
      'file_size_kb': 0,
      'description': notes.trim(),
      'is_offline_cached': true,
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final matResponse =
          await _apiClient.post(ApiEndpoints.materials, body: materialPayload);
      final matJson = Map<String, dynamic>.from(matResponse as Map);
      final createdMatId =
          asNullableInt(matJson['material_id'] ?? matJson['id']);

      if (lessonGradeLevelId != null && createdMatId != null) {
        final linkPayload = <String, dynamic>{
          'lesson_grade_level': int.parse(lessonGradeLevelId),
          'material_id': createdMatId,
          'usage_instructions': notes.trim(),
        };
        final linkResponse = await _apiClient.post(
          _lessonGradeMaterialsEndpoint,
          body: linkPayload,
        );
        final created = LessonMaterial.fromJson(
          Map<String, dynamic>.from(linkResponse as Map),
        ).copyWith(
          lessonPlanId: lessonPlanId,
          lessonGradeLevelId: lessonGradeLevelId,
          gradeLevelName: gradeLevelName,
          materialServerId: createdMatId,
          title: title.trim(),
          resourceUrl: resourceUrl.trim(),
        );
        await _cache.appendChild(lessonPlanId, material: created);
        return created;
      }

      final created = LessonMaterial.fromJson(matJson).copyWith(
        lessonPlanId: lessonPlanId,
        gradeLevelName: gradeLevelName,
      );
      await _cache.appendChild(lessonPlanId, material: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('mat');
      final draft = LessonMaterial(
        id: tempId,
        lessonPlanId: lessonPlanId,
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
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
        payload: materialPayload,
        tempClientId: tempId,
        primaryKeyField: 'material_id',
        dependsOnTempIds: [
          ...deps,
          if (isLglTemp) lessonGradeLevelId,
        ],
      );
      await _cache.appendChild(lessonPlanId, material: draft);
      return draft;
    }
  }

  Future<LessonMaterial> updateMaterial({
    required String lessonPlanId,
    required LessonMaterial existing,
    String? lessonGradeLevelId,
    String gradeLevelName = '',
    required String title,
    String resourceUrl = '',
    String notes = '',
  }) async {
    final isTemp = existing.id.startsWith(IdMappingStore.tempPrefix);
    final isLglTemp = lessonGradeLevelId != null &&
        lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix);

    final matId = existing.materialServerId ?? existing.serverId;
    final matEndpoint = '/curriculum/materials/${matId ?? existing.id}/';
    final matPayload = <String, dynamic>{
      'file_name': title.trim(),
      if (resourceUrl.trim().isNotEmpty) 'file_url': resourceUrl.trim(),
      'description': notes.trim(),
    };

    try {
      if (isTemp || isLglTemp) {
        throw ApiException(message: 'Record is local draft', isOffline: true);
      }
      await _apiClient.patch(matEndpoint, body: matPayload);

      if (existing.materialServerId != null && existing.serverId != null) {
        await _apiClient.patch(
          '$_lessonGradeMaterialsEndpoint${existing.serverId}/',
          body: {
            if (lessonGradeLevelId != null)
              'lesson_grade_level': int.parse(lessonGradeLevelId),
            'usage_instructions': notes.trim(),
          },
        );
      }

      final updated = existing.copyWith(
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        title: title.trim(),
        resourceUrl: resourceUrl.trim(),
        notes: notes.trim(),
      );
      await _cache.replaceChild(lessonPlanId, material: updated);
      return updated;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final optimistic = existing.copyWith(
        lessonGradeLevelId: lessonGradeLevelId,
        gradeLevelName: gradeLevelName,
        title: title.trim(),
        resourceUrl: resourceUrl.trim(),
        notes: notes.trim(),
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'material_update',
        method: 'PATCH',
        endpoint: matEndpoint,
        payload: matPayload,
        dependsOnTempIds: [
          if (isTemp) existing.id,
          if (isLglTemp) lessonGradeLevelId,
        ],
      );
      await _cache.replaceChild(lessonPlanId, material: optimistic);
      return optimistic;
    }
  }

  Future<void> deleteMaterial({
    required String lessonPlanId,
    required LessonMaterial material,
  }) async {
    final isTemp = material.id.startsWith(IdMappingStore.tempPrefix);
    final endpoint = material.materialServerId != null
        ? '$_lessonGradeMaterialsEndpoint${material.id}/'
        : '/curriculum/materials/${material.id}/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _cache.removeChild(lessonPlanId, materialId: material.id);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'material_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [material.id] : const [],
      );
      await _cache.removeChild(lessonPlanId, materialId: material.id);
    }
  }

  // ---------------- FORK & APPROVAL ----------------

  Future<LessonPlan> forkLessonPlan(int serverId) async {
    final response =
        await _apiClient.post(ApiEndpoints.lessonPlanFork(serverId));
    final forked = LessonPlan.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
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
      final updated = LessonPlan.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
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
