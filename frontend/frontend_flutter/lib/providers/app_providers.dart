import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/network_sync_manager.dart';
import '../services/token_service.dart';
import '../services/local_storage_service.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';

// --- Local Storage Service Provider ---
final localStorageProvider = Provider<LocalStorageService>((ref) => LocalStorageService());

// --- Token Service Provider ---
final tokenServiceProvider = Provider<TokenService>((ref) => TokenService());

// =====================================================================
// Connection status (drives the banner shown on every screen)
// =====================================================================

/// true = the DEVICE has a network connection (says nothing about the server).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> r) => !r.contains(ConnectivityResult.none);

  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});

/// Did the server answer the last request? Updated by ApiClient on every call.
class ServerReachableNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void report(bool reachable) {
    if (state != reachable) state = reachable;
  }
}

final serverReachableProvider =
    NotifierProvider<ServerReachableNotifier, bool>(ServerReachableNotifier.new);

/// Which data sources are currently showing saved (cached) data instead of
/// fresh data from the server, e.g. {'classrooms', 'lesson_plans'}.
class CachedFallbackNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void mark(String source, bool usingCache) {
    final contains = state.contains(source);
    if (usingCache && !contains) {
      state = {...state, source};
    } else if (!usingCache && contains) {
      state = {...state}..remove(source);
    }
  }
}

final cachedFallbackProvider =
    NotifierProvider<CachedFallbackNotifier, Set<String>>(CachedFallbackNotifier.new);

// --- API Service Provider ---
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();

  apiService.onUnauthenticated = () {
    ref.read(authProvider.notifier).logout();
  };

  // Every request reports whether the server answered.
  apiService.onReachabilityChanged = (reachable) {
    ref.read(serverReachableProvider.notifier).report(reachable);
  };

  return apiService;
});

// --- Offline sync (queues changes made offline and uploads them later) ---
// Watched once in main.dart so it starts listening for connectivity changes.
final networkSyncManagerProvider = Provider<NetworkSyncManager>((ref) {
  final manager = NetworkSyncManager(
    ref.watch(apiServiceProvider),
    ref.watch(localStorageProvider),
    ref.watch(tokenServiceProvider),
  );
  // After queued changes upload, reload the lists from the server.
  manager.onSynced = () => ref.invalidate(classroomsProvider);
  manager.initialize();

  // Retry: upload queued changes and re-fetch the lists, so the banner clears
  // itself once the server answers again.
  void probeServer() {
    if (ref.read(authProvider).value != true) return;
    if (ref.read(classroomsProvider).isLoading) return; // a request is in flight
    unawaited(manager.syncPendingData());
    ref.invalidate(classroomsProvider);
  }

  // Device regained a connection -> try right away.
  ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
    if (next.value == true && previous?.value == false) probeServer();
  });

  // Still degraded (server not answering, or showing saved data) -> retry
  // every 30 seconds. Does nothing while everything is healthy.
  final retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    final degraded = !ref.read(serverReachableProvider) ||
        ref.read(cachedFallbackProvider).isNotEmpty;
    if (degraded) probeServer();
  });
  ref.onDispose(retryTimer.cancel);

  ref.onDispose(manager.dispose);
  return manager;
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

  /// Throws on failure. The auth state is NOT set to loading here, so the
  /// LoginScreen stays on screen (keeping what the user typed). Show your own
  /// spinner / error message in the screen around this call.
  Future<void> login(String username, String password) async {
    final tokenService = ref.read(tokenServiceProvider);
    final name = username.trim();

    final token = await ref.read(apiServiceProvider).login(name, password);
    await tokenService.saveToken(token);
    await tokenService.saveUsername(name);

    state = const AsyncValue.data(true);

    // Upload anything this user queued while offline or logged out.
    unawaited(ref.read(networkSyncManagerProvider).syncPendingData());
  }

  Future<void> logout() async {
    if (state.value == false) return; // already logged out (prevents loops)

    state = const AsyncValue.data(false);
    await ref.read(tokenServiceProvider).clearToken();
    // Clears cached server data only; unsynced offline changes stay queued.
    await ref.read(localStorageProvider).clearAllCache();

    // Drop the previous user's data from memory.
    ref.invalidate(classroomsProvider);
    ref.invalidate(lessonPlansProvider);
    ref.invalidate(cachedFallbackProvider);
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

// --- Offline-First Data Fetch Providers ---

final lessonPlansProvider = FutureProvider<List<LessonPlanModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final localStorage = ref.watch(localStorageProvider);
  final search = ref.watch(lessonPlanSearchQueryProvider);
  final area = ref.watch(lessonPlanAreaFilterProvider);

  // Tells the banner whether this list is showing saved data.
  void markCached(bool usingCache) {
    if (ref.mounted) {
      ref.read(cachedFallbackProvider.notifier).mark('lesson_plans', usingCache);
    }
  }

  // Debounce typing: if the query changes again within 400 ms, this run is
  // disposed and the request below never fires.
  if (search.isNotEmpty) {
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (cancelled) throw Exception('Superseded by a newer search');
  }

  try {
    final remotePlans = await apiService.fetchLessonPlans(
      search: search,
      learningArea: area,
    );

    // Update cache only if no active search/filter string is applied
    if (search.isEmpty && area.isEmpty) {
      await localStorage.cacheLessonPlans(remotePlans);
    }
    markCached(false);
    return remotePlans;
  } catch (e) {
    // Return cached plans if network fails
    final cachedPlans = localStorage.getCachedLessonPlans();
    if (cachedPlans.isNotEmpty) {
      markCached(true);
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
  Future<List<ClassroomModel>> build() => _fetchOrFallback();

  /// Creates a classroom. Returns true if it reached the server, or false if
  /// there was no connection and it was queued to upload automatically later.
  /// Throws [ApiException] if the server rejected it (e.g. validation error),
  /// so the screen can show the message.
  Future<bool> addClassroom(ClassroomModel classroom) async {
    final sentNow =
        await ref.read(networkSyncManagerProvider).createClassroom(classroom);

    // Keep the current list visible while reloading (no loading flash).
    state = await AsyncValue.guard(_fetchOrFallback);
    return sentNow;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetchOrFallback);
  }

  /// Tells the banner whether classrooms are showing saved data.
  void _markCached(bool usingCache) {
    if (ref.mounted) {
      ref.read(cachedFallbackProvider.notifier).mark('classrooms', usingCache);
    }
  }

  /// Fetch remote data, falling back to the cache (plus classrooms that are
  /// still waiting to upload) when the server can't be reached.
  Future<List<ClassroomModel>> _fetchOrFallback() async {
    // Logged out: don't hit the server without a token.
    if (ref.read(authProvider).value == false) return const [];

    final localStorage = ref.read(localStorageProvider);

    try {
      final remoteClassrooms = await ref.read(apiServiceProvider).fetchClassrooms();
      await localStorage.cacheClassrooms(remoteClassrooms);
      _markCached(false);
      return remoteClassrooms;
    } catch (e) {
      final drafts =
          await ref.read(networkSyncManagerProvider).pendingClassroomDrafts();
      final combined = [...localStorage.getCachedClassrooms(), ...drafts];
      if (combined.isNotEmpty) {
        _markCached(true);
        return combined;
      }
      rethrow;
    }
  }
}

final classroomsProvider =
    AsyncNotifierProvider<ClassroomsNotifier, List<ClassroomModel>>(
  ClassroomsNotifier.new,
);
