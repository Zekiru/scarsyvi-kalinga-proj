import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';

// --- API Service Provider ---
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// --- Search Query Notifier ---
class LessonPlanSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) => state = query;
  void clear() => state = '';
}

final lessonPlanSearchQueryProvider =
    NotifierProvider<LessonPlanSearchQueryNotifier, String>(
  LessonPlanSearchQueryNotifier.new,
);

// --- Learning Area Filter Notifier ---
class LessonPlanAreaFilterNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateArea(String area) => state = area;
  void clear() => state = '';
}

final lessonPlanAreaFilterProvider =
    NotifierProvider<LessonPlanAreaFilterNotifier, String>(
  LessonPlanAreaFilterNotifier.new,
);

// --- Lesson Plans FutureProvider ---
final lessonPlansProvider = FutureProvider<List<LessonPlanModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final search = ref.watch(lessonPlanSearchQueryProvider);
  final area = ref.watch(lessonPlanAreaFilterProvider);
  return apiService.fetchLessonPlans(search: search, learningArea: area);
});

// --- Classrooms AsyncNotifier ---
class ClassroomsNotifier extends AsyncNotifier<List<ClassroomModel>> {
  @override
  Future<List<ClassroomModel>> build() async {
    return ref.read(apiServiceProvider).fetchClassrooms();
  }

  Future<void> addClassroom(ClassroomModel classroom) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(apiServiceProvider).createClassroom(classroom);
      return ref.read(apiServiceProvider).fetchClassrooms();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(apiServiceProvider).fetchClassrooms();
    });
  }
}

final classroomsProvider =
    AsyncNotifierProvider<ClassroomsNotifier, List<ClassroomModel>>(
  ClassroomsNotifier.new,
);
