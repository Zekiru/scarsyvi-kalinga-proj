import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/local_storage_service.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';

// --- Local Storage Service Provider ---
final localStorageProvider = Provider<LocalStorageService>((ref) => LocalStorageService());

// --- Token Service Provider ---
final tokenServiceProvider = Provider<TokenService>((ref) => TokenService()); // cite: 12

// --- API Service Provider with 401 Unauthorized Callback Listener ---
final apiServiceProvider = Provider<ApiService>((ref) { // cite: 12
  final apiService = ApiService(); // cite: 12
  apiService.onUnauthenticated = () { // cite: 12
    ref.read(authProvider.notifier).logout(); // cite: 12
  };
  return apiService; // cite: 12
});

// --- Auth State Notifier ---
class AuthNotifier extends Notifier<AsyncValue<bool>> { // cite: 12
  @override
  AsyncValue<bool> build() { // cite: 12
    _checkAuthStatus(); // cite: 12
    return const AsyncValue.loading(); // cite: 12
  }

  Future<void> _checkAuthStatus() async { // cite: 12
    final token = await ref.read(tokenServiceProvider).getToken(); // cite: 12
    state = AsyncValue.data(token != null && token.isNotEmpty); // cite: 12
  }

  Future<void> login(String username, String password) async { // cite: 12
    state = const AsyncValue.loading(); // cite: 12
    try {
      final tokenService = ref.read(tokenServiceProvider); // cite: 12
      final apiService = ref.read(apiServiceProvider); // cite: 12

      final token = await apiService.login(username, password); // cite: 12
      await tokenService.saveToken(token); // cite: 12

      state = const AsyncValue.data(true); // cite: 12
    } catch (e, stack) { // cite: 12
      state = AsyncValue.error(e, stack); // cite: 12
      rethrow; // cite: 12
    }
  }

  Future<void> logout() async { // cite: 12
    await ref.read(tokenServiceProvider).clearToken(); // cite: 12
    await ref.read(localStorageProvider).clearAllCache();
    state = const AsyncValue.data(false); // cite: 12
  }
}

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<bool>>( // cite: 12
  AuthNotifier.new, // cite: 12
);

// --- Search & Filter Notifiers ---
class LessonPlanSearchQueryNotifier extends Notifier<String> { // cite: 12
  @override
  String build() => ''; // cite: 12

  void updateQuery(String query) => state = query; // cite: 12
  void clear() => state = ''; // cite: 12
}

final lessonPlanSearchQueryProvider =
    NotifierProvider<LessonPlanSearchQueryNotifier, String>( // cite: 12
  LessonPlanSearchQueryNotifier.new, // cite: 12
);

class LessonPlanAreaFilterNotifier extends Notifier<String> { // cite: 12
  @override
  String build() => ''; // cite: 12

  void updateArea(String area) => state = area; // cite: 12
  void clear() => state = ''; // cite: 12
}

final lessonPlanAreaFilterProvider =
    NotifierProvider<LessonPlanAreaFilterNotifier, String>( // cite: 12
  LessonPlanAreaFilterNotifier.new, // cite: 12
);

// --- Offline-First Data Fetch Providers ---

final lessonPlansProvider = FutureProvider<List<LessonPlanModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider); // cite: 12
  final localStorage = ref.watch(localStorageProvider);
  final search = ref.watch(lessonPlanSearchQueryProvider); // cite: 12
  final area = ref.watch(lessonPlanAreaFilterProvider); // cite: 12

  final cachedPlans = localStorage.getCachedLessonPlans();

  try {
    final remotePlans = await apiService.fetchLessonPlans(
      search: search,
      learningArea: area,
    ); // cite: 12

    // Update cache only if no active search/filter string is applied
    if (search.isEmpty && area.isEmpty) {
      await localStorage.cacheLessonPlans(remotePlans);
    }
    return remotePlans;
  } catch (e) {
    // Return cached plans if network fails
    if (cachedPlans.isNotEmpty) {
      return cachedPlans.where((plan) {
        final matchesSearch = search.isEmpty ||
            plan.lpTitle.toLowerCase().contains(search.toLowerCase());
        final matchesArea = area.isEmpty || plan.learningArea == area;
        return matchesSearch && matchesArea;
      }).toList();
    }
    rethrow;
  }
});

class ClassroomsNotifier extends AsyncNotifier<List<ClassroomModel>> {
  @override
  Future<List<ClassroomModel>> build() async {
    final localStorage = ref.read(localStorageProvider);
    final apiService = ref.read(apiServiceProvider);

    final cachedClassrooms = localStorage.getCachedClassrooms();

    try {
      final remoteClassrooms = await apiService.fetchClassrooms();
      await localStorage.cacheClassrooms(remoteClassrooms);
      return remoteClassrooms;
    } catch (e) {
      if (cachedClassrooms.isNotEmpty) {
        return cachedClassrooms;
      }
      rethrow;
    }
  }

  Future<void> addClassroom(ClassroomModel classroom) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final localStorage = ref.read(localStorageProvider);
      
      try {
        await ref.read(apiServiceProvider).createClassroom(classroom);
      } catch (_) {
        await localStorage.saveClassroom(classroom);
      }

      return _fetchOrFallback();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _fetchOrFallback();
    });
  }

  /// Helper method to fetch remote data with local cache fallback
  Future<List<ClassroomModel>> _fetchOrFallback() async {
    final localStorage = ref.read(localStorageProvider);
    final apiService = ref.read(apiServiceProvider);
    final cachedClassrooms = localStorage.getCachedClassrooms();

    try {
      final remoteClassrooms = await apiService.fetchClassrooms();
      await localStorage.cacheClassrooms(remoteClassrooms);
      return remoteClassrooms;
    } catch (e) {
      if (cachedClassrooms.isNotEmpty) {
        return cachedClassrooms;
      }
      rethrow;
    }
  }
}

final classroomsProvider =
    AsyncNotifierProvider<ClassroomsNotifier, List<ClassroomModel>>( // cite: 12
  ClassroomsNotifier.new, // cite: 12
);
