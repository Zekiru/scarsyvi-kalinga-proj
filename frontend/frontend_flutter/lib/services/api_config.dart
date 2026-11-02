import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Where the API lives and how long we wait for it.
class ApiConfig {
  const ApiConfig._();

  static const String productionUrl =
      'https://scarsyvi-kalinga-proj.onrender.com/api/v1';

  /// Long timeout to survive Render free-tier cold starts (spins down after 15 mins).
  static const Duration requestTimeout = Duration(seconds: 45);

  /// Local dev URL per platform (the Android emulator reaches the host at 10.0.2.2).
  static String get localBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  /// Production by default. Override with `--dart-define=BASE_URL=...`
  /// or point at your local server with `--dart-define=USE_LOCAL_BACKEND=true`.
  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    const useLocal = bool.fromEnvironment('USE_LOCAL_BACKEND');
    return useLocal ? localBaseUrl : productionUrl;
  }
}
