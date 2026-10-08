import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class NetworkSyncManager {
  final ApiService _apiService;
  final LocalStorageService _localStorage;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkSyncManager(this._apiService, this._localStorage);

  void initialize() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        syncPendingData();
      }
    });
  }

  Future<void> syncPendingData() async {
    // 1. Fetch cached items marked as unsynced
    // 2. Post/Put them to your Django backend via ApiService
    // 3. Update local Hive entries upon successful response
  }

  void dispose() {
    _subscription?.cancel();
  }
}
