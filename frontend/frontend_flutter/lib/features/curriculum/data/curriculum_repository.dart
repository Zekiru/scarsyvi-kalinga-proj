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

  /// Fetches all pages from a DRF list endpoint so child items on page 2+ are never dropped.
  Future<List<dynamic>> _fetchAllItems(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final all = <dynamic>[];
    String? nextEndpoint = endpoint;
    Map<String, String>? params = queryParams;
    int guard = 0;

    while (nextEndpoint != null && guard < 20) {
      guard++;
      final response = await _apiClient.get(nextEndpoint, queryParams: params);
      all.addAll(_extractList(response));

      if (response is Map<String, dynamic> && response['next'] is String) {
        final rawNext = response['next'] as String;
        if (rawNext.isEmpty) {
          nextEndpoint = null;
        } else {
          final uri = Uri.tryParse(rawNext);
          if (uri != null) {
            var path = uri.path;
            if (path.startsWith('/api/v1')) {
              path = path.substring('/api/v1'.length);
            }
            nextEndpoint = path;
            params = uri.queryParameters.isEmpty ? null : uri.queryParameters;
          } else {
            nextEndpoint = null;
          }
        }
      } else {
        nextEndpoint = null;
      }
    }
    return all;
  }

  List<GradeLevel> getCachedGradeLevels() => _cache.getGradeLevels();
  List<LessonPlan> getCachedLessonPlans() => _cache.getLessonPlans();

  Future<List<GradeLevel>> fetchGradeLevels() async {
    try {
      final items = await _fetchAllItems(ApiEndpoints.gradeLevels);
      final levels = parseModelList(items, GradeLevel.fromJson);
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
      final items = await _fetchAllItems(
        ApiEndpoints.lessonPlans,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final serverPlans = parseModelList(items, LessonPlan.fromJson);
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

      // LessonPlan.gradeLevels from the base serializer may only contain summary
      // grade objects (gl_id + grade_level_name) without LessonGradeLevel IDs or standards.
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
          needsGradeLevelsHydration: needsGradeLevelsHydration,
        );
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
    LessonPlan plan, {
    required bool needsGradeLevelsHydration,
  }) async {
    final planIdStr = serverId.toString();

    // 1. Resolve full LessonGradeLevel records first so we have their real primary keys (`id`)
    // and standards (`i_content_standard`, `i_performance_standard`, etc.).
    var gradeLevels = plan.gradeLevels;
    if (needsGradeLevelsHydration) {
      final rawLgls = await _fetchAllItems(ApiEndpoints.lessonGradeLevels)
          .catchError((_) => const <dynamic>[]);
      final parsedLgls = parseModelList(rawLgls, LessonGradeLevel.fromJson)
          .where((e) => e.lessonPlanId == planIdStr)
          .toList();

      if (parsedLgls.isNotEmpty) {
        // Fill in any missing gradeLevelName from the summary list on `plan.gradeLevels`
        final nameByGlId = <int, String>{
          for (final g in plan.gradeLevels)
            if (g.gradeLevelName.isNotEmpty) g.gradeLevelId: g.gradeLevelName,
        };
        gradeLevels = parsedLgls.map((lgl) {
          if (lgl.gradeLevelName.isEmpty &&
              nameByGlId.containsKey(lgl.gradeLevelId)) {
            return lgl.copyWith(gradeLevelName: nameByGlId[lgl.gradeLevelId]!);
          }
          return lgl;
        }).toList();
      }
    }

    final lglMap = <String, String>{
      for (final gl in gradeLevels)
        if (gl.id.isNotEmpty)
          gl.id: gl.gradeLevelName.isNotEmpty
              ? gl.gradeLevelName
              : 'Grade ${gl.gradeLevelId}',
    };
    final validLglIds = lglMap.keys.toSet();

    bool belongsToPlan(String? lglId, String lpId) {
      if (lglId != null && lglId.isNotEmpty && validLglIds.contains(lglId)) {
        return true;
      }
      if (lpId.isNotEmpty && lpId == planIdStr) return true;
      return false;
    }

    // 2. Fetch flows, gradings, and materials concurrently if empty on the base response
    final results = await Future.wait<List<dynamic>>([
      if (plan.flows.isEmpty)
        _fetchAllItems(ApiEndpoints.lessonFlows)
            .catchError((_) => const <dynamic>[])
      else
        Future.value(const <dynamic>[]),
      if (plan.gradings.isEmpty)
        _fetchAllItems(ApiEndpoints.lessonGradings)
            .catchError((_) => const <dynamic>[])
      else
        Future.value(const <dynamic>[]),
      if (plan.materials.isEmpty)
        _fetchAllItems(ApiEndpoints.materials)
            .catchError((_) => const <dynamic>[])
      else
        Future.value(const <dynamic>[]),
    ]);

    var flows = plan.flows.isNotEmpty
        ? plan.flows
        : gradeLevels.expand((gl) => gl.flows).toList();
    if (flows.isEmpty && results[0].isNotEmpty) {
      flows = parseModelList(results[0], LessonFlow.fromJson)
          .where((f) => belongsToPlan(f.lessonGradeLevelId, f.lessonPlanId))
          .toList();
    }
    flows = flows
        .map((f) => (f.gradeLevelName.isEmpty &&
                f.lessonGradeLevelId != null &&
                lglMap.containsKey(f.lessonGradeLevelId))
            ? f.copyWith(gradeLevelName: lglMap[f.lessonGradeLevelId]!)
            : f)
        .toList();

    var gradings = plan.gradings.isNotEmpty
        ? plan.gradings
        : gradeLevels.expand((gl) => gl.gradingTasks).toList();
    if (gradings.isEmpty && results[1].isNotEmpty) {
      gradings = parseModelList(results[1], LessonGrading.fromJson)
          .where((g) => belongsToPlan(g.lessonGradeLevelId, g.lessonPlanId))
          .toList();
    }
    gradings = gradings
        .map((g) => (g.gradeLevelName.isEmpty &&
                g.lessonGradeLevelId != null &&
                lglMap.containsKey(g.lessonGradeLevelId))
            ? g.copyWith(gradeLevelName: lglMap[g.lessonGradeLevelId]!)
            : g)
        .toList();

    var materials = plan.materials.isNotEmpty
        ? plan.materials
        : gradeLevels.expand((gl) => gl.materials).toList();
    if (materials.isEmpty && results[2].isNotEmpty) {
      materials = parseModelList(results[2], LessonMaterial.fromJson)
          .where((m) => belongsToPlan(m.lessonGradeLevelId, m.lessonPlanId))
          .toList();
    }
    materials = materials
        .map((m) => (m.gradeLevelName.isEmpty &&
                m.lessonGradeLevelId != null &&
                lglMap.containsKey(m.lessonGradeLevelId))
            ? m.copyWith(gradeLevelName: lglMap[m.lessonGradeLevelId]!)
            : m)
        .toList();

    // Attach hydrated flows/gradings/materials onto their corresponding LessonGradeLevel cards
    final hydratedGradeLevels = gradeLevels.map((gl) {
      if (gl.id.isEmpty) return gl;
      final glFlows = flows.where((f) => f.lessonGradeLevelId == gl.id).toList();
      final glGradings =
          gradings.where((g) => g.lessonGradeLevelId == gl.id).toList();
      final glMaterials =
          materials.where((m) => m.lessonGradeLevelId == gl.id).toList();
      return gl.copyWith(
        flows: gl.flows.isNotEmpty ? gl.flows : glFlows,
        gradingTasks:
            gl.gradingTasks.isNotEmpty ? gl.gradingTasks : glGradings,
        materials: gl.materials.isNotEmpty ? gl.materials : glMaterials,
      );
    }).toList();

    return plan.copyWith(
      gradeLevels: hydratedGradeLevels,
      flows: flows,
      gradings: gradings,
      materials: materials,
    );
  }

  Future<LessonPlan> createLessonPlan({
    required String title,
    required String subject,
    required String primaryLanguage,
    required String suggestedDemographic,
    String multigradeModel = '',
    String sharedSubTheme = '',
    String learnerContext = '',
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
        'multigrade_model': multigradeModel.trim(),
      if (sharedSubTheme.trim().isNotEmpty)
        'shared_sub_theme': sharedSubTheme.trim(),
      if (learnerContext.trim().isNotEmpty)
        'learner_context': learnerContext.trim(),
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
        multigradeModel: multigradeModel.trim(),
        sharedSubTheme: sharedSubTheme.trim(),
        learnerContext: learnerContext.trim(),
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
    final payload = <String, dynamic>{
      'lp': isParentTemp ? lessonPlanId : int.parse(lessonPlanId),
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
      if (isParentTemp) {
        throw ApiException(
            message: 'Parent plan is offline draft', isOffline: true);
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
    final payload = <String, dynamic>{
      'lesson_grade_level':
          lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix)
              ? lessonGradeLevelId
              : int.parse(lessonGradeLevelId),
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
      final created = LessonFlow.fromJson(response as Map<String, dynamic>)
          .copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.appendChild(lessonPlanId, flow: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonFlow(
        id: IdMappingStore.generateTempId('flow'),
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
        dependsOnTempIds: deps,
      );
      await _cache.appendChild(lessonPlanId, flow: draft);
      return draft;
    }
  }

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
    final payload = <String, dynamic>{
      'lesson_grade_level':
          lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix)
              ? lessonGradeLevelId
              : int.parse(lessonGradeLevelId),
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
      final created = LessonGrading.fromJson(response as Map<String, dynamic>)
          .copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.appendChild(lessonPlanId, grading: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonGrading(
        id: IdMappingStore.generateTempId('grad'),
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
        dependsOnTempIds: deps,
      );
      await _cache.appendChild(lessonPlanId, grading: draft);
      return draft;
    }
  }

  Future<LessonMaterial> addMaterial({
    required String lessonPlanId,
    String? lessonGradeLevelId,
    String gradeLevelName = '',
    required String title,
    String materialType = 'DOCUMENT',
    String resourceUrl = '',
    String notes = '',
  }) async {
    final deps = _collectDependencies(lessonPlanId, lessonGradeLevelId);
    final payload = <String, dynamic>{
      if (lessonGradeLevelId != null)
        'lesson_grade_level':
            lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix)
                ? lessonGradeLevelId
                : int.parse(lessonGradeLevelId),
      'lesson_plan': lessonPlanId.startsWith(IdMappingStore.tempPrefix)
          ? lessonPlanId
          : int.parse(lessonPlanId),
      'title': title.trim(),
      'material_type': materialType,
      'resource_url': resourceUrl.trim(),
      'notes': notes.trim(),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.materials, body: payload);
      final created = LessonMaterial.fromJson(response as Map<String, dynamic>)
          .copyWith(lessonPlanId: lessonPlanId, gradeLevelName: gradeLevelName);
      await _cache.appendChild(lessonPlanId, material: created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final draft = LessonMaterial(
        id: IdMappingStore.generateTempId('mat'),
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
        payload: payload,
        dependsOnTempIds: deps,
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

  List<String> _collectDependencies(
      String lessonPlanId, String? lessonGradeLevelId) {
    return [
      if (lessonPlanId.startsWith(IdMappingStore.tempPrefix)) lessonPlanId,
      if (lessonGradeLevelId != null &&
          lessonGradeLevelId.startsWith(IdMappingStore.tempPrefix))
        lessonGradeLevelId,
    ];
  }
}
