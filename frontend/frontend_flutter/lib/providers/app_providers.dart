import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';

// --- Token Service Provider ---
final tokenServiceProvider = Provider<TokenService>((ref) => TokenService());

// --- API Service Provider with 401 Unauthorized Callback Listener ---
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();
  apiService.onUnauthenticated = () {
    ref.read(authProvider.notifier).logout();
  };
  return apiService;
});

// --- Auth State Notifier ---
class AuthNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() {
    _checkAuthStatus();
    return const AsyncValue.loading();
  }

  Future<void> _checkAuthStatus() async {
    final token = await ref.read(tokenServiceProvider).getToken();
    state = AsyncValue.data(token != null && token.isNotEmpty);
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final tokenService = ref.read(tokenServiceProvider);
      final apiService = ref.read(apiServiceProvider);

      final token = await apiService.login(username, password);
      await tokenService.saveToken(token);

      state = const AsyncValue.data(true);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(tokenServiceProvider).clearToken();
    state = const AsyncValue.data(false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<bool>>(
  AuthNotifier.new,
);

// --- Search & Filter Notifiers ---
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

// --- Data Fetch Providers ---
final lessonPlansProvider = FutureProvider<List<LessonPlanModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final search = ref.watch(lessonPlanSearchQueryProvider);
  final area = ref.watch(lessonPlanAreaFilterProvider);
  return apiService.fetchLessonPlans(search: search, learningArea: area);
});

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
