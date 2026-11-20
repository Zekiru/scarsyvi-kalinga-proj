import 'dart:convert';
import 'package:hive/hive.dart';
import 'curriculum_models.dart';

class CurriculumCacheStore {
  const CurriculumCacheStore(this._box);

  final Box<String> _box;

  static const String _gradeLevelsKey = 'grade_levels';
  static const String _lessonPlansKey = 'lesson_plans';
  static String _lessonDetailKey(String id) => 'lesson_plan_$id';

  List<GradeLevel> getGradeLevels() {
    final raw = _box.get(_gradeLevelsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return parseModelList(jsonDecode(raw), GradeLevel.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveGradeLevels(List<GradeLevel> levels) async {
    await _box.put(
      _gradeLevelsKey,
      jsonEncode(levels.map((e) => e.toJson()).toList()),
    );
  }

  List<LessonPlan> getLessonPlans() {
    final raw = _box.get(_lessonPlansKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return LessonPlan.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveLessonPlans(List<LessonPlan> plans) async {
    await _box.put(_lessonPlansKey, LessonPlan.encodeList(plans));
  }

  LessonPlan? getLessonPlanDetail(String id) {
    final raw = _box.get(_lessonDetailKey(id));
    if (raw != null && raw.isNotEmpty) {
      try {
        return LessonPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return getLessonPlans().where((p) => p.id == id).firstOrNull;
  }

  Future<void> saveDetail(LessonPlan plan) async {
    await _box.put(_lessonDetailKey(plan.id), jsonEncode(plan.toJson()));
    final currentList = getLessonPlans();
    final idx = currentList.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      currentList[idx] = plan;
    } else {
      currentList.insert(0, plan);
    }
    await saveLessonPlans(currentList);
  }

  Future<void> appendChild(
    String lessonPlanId, {
    LessonGradeLevel? gradeLevel,
    LessonFlow? flow,
    LessonGrading? grading,
    LessonMaterial? material,
  }) async {
    final existing = getLessonPlanDetail(lessonPlanId);
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
    await saveDetail(updated);
  }
}
