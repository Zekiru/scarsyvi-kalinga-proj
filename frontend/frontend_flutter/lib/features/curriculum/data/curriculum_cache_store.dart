import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'curriculum_models.dart';

class CurriculumCacheStore {
  CurriculumCacheStore(this._box);

  final Box<String> _box;

  static const _gradeLevelsKey = 'grade_levels';
  static const _lessonPlansKey = 'lesson_plans';
  static String _lessonDetailKey(String id) => 'lesson_plan_detail_$id';

  List<GradeLevel> getGradeLevels() {
    final raw = _box.get(_gradeLevelsKey);
    if (raw == null || raw.isEmpty) return [];
    return parseModelList(jsonDecode(raw), GradeLevel.fromJson);
  }

  Future<void> saveGradeLevels(List<GradeLevel> items) async {
    await _box.put(
      _gradeLevelsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  List<LessonPlan> getLessonPlans() {
    final raw = _box.get(_lessonPlansKey);
    if (raw == null || raw.isEmpty) return [];
    return List<LessonPlan>.of(LessonPlan.decodeList(raw));
  }

  Future<void> saveLessonPlans(List<LessonPlan> items) async {
    await _box.put(_lessonPlansKey, LessonPlan.encodeList(items));
  }

  LessonPlan? getLessonPlanDetail(String id) {
    final raw = _box.get(_lessonDetailKey(id));
    if (raw != null && raw.isNotEmpty) {
      return LessonPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    for (final p in getLessonPlans()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> saveDetail(LessonPlan plan) async {
    await _box.put(_lessonDetailKey(plan.id), jsonEncode(plan.toJson()));
    final currentList = List<LessonPlan>.of(getLessonPlans());
    final idx = currentList.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      currentList[idx] = plan;
    } else {
      currentList.insert(0, plan);
    }
    await saveLessonPlans(currentList);
  }

  Future<void> removeLessonPlan(String id) async {
    await _box.delete(_lessonDetailKey(id));
    final currentList = List<LessonPlan>.of(getLessonPlans())
      ..removeWhere((p) => p.id == id);
    await saveLessonPlans(currentList);
  }

  Future<void> appendChild(
    String lessonPlanId, {
    LessonGradeLevel? gradeLevel,
    LessonFlow? flow,
    LessonGrading? grading,
    LessonMaterial? material,
  }) async {
    final plan = getLessonPlanDetail(lessonPlanId);
    if (plan == null) return;

    final updatedGradeLevels = List<LessonGradeLevel>.of(plan.gradeLevels);
    if (gradeLevel != null) {
      updatedGradeLevels.add(gradeLevel);
    }

    final updated = plan.copyWith(
      gradeLevels: updatedGradeLevels,
      flows: flow != null ? [...plan.flows, flow] : plan.flows,
      gradings: grading != null ? [...plan.gradings, grading] : plan.gradings,
      materials:
          material != null ? [...plan.materials, material] : plan.materials,
    );
    await saveDetail(updated);
  }

  Future<void> replaceChild(
    String lessonPlanId, {
    LessonGradeLevel? gradeLevel,
    LessonFlow? flow,
    LessonGrading? grading,
    LessonMaterial? material,
  }) async {
    final plan = getLessonPlanDetail(lessonPlanId);
    if (plan == null) return;

    final updated = plan.copyWith(
      gradeLevels: gradeLevel != null
          ? plan.gradeLevels
              .map((g) => g.id == gradeLevel.id ? gradeLevel : g)
              .toList()
          : plan.gradeLevels,
      flows: flow != null
          ? plan.flows.map((f) => f.id == flow.id ? flow : f).toList()
          : plan.flows,
      gradings: grading != null
          ? plan.gradings.map((g) => g.id == grading.id ? grading : g).toList()
          : plan.gradings,
      materials: material != null
          ? plan.materials
              .map((m) => m.id == material.id ? material : m)
              .toList()
          : plan.materials,
    );
    await saveDetail(updated);
  }

  Future<void> removeChild(
    String lessonPlanId, {
    String? gradeLevelId,
    String? flowId,
    String? gradingId,
    String? materialId,
  }) async {
    final plan = getLessonPlanDetail(lessonPlanId);
    if (plan == null) return;

    final updated = plan.copyWith(
      gradeLevels: gradeLevelId != null
          ? plan.gradeLevels.where((g) => g.id != gradeLevelId).toList()
          : plan.gradeLevels,
      flows: flowId != null
          ? plan.flows.where((f) => f.id != flowId).toList()
          : plan.flows,
      gradings: gradingId != null
          ? plan.gradings.where((g) => g.id != gradingId).toList()
          : plan.gradings,
      materials: materialId != null
          ? plan.materials.where((m) => m.id != materialId).toList()
          : plan.materials,
    );
    await saveDetail(updated);
  }
}
