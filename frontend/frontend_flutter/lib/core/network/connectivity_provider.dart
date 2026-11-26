import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_endpoints.dart';

enum ConnectionStatus {
  online,
  offline,
  serverUnreachable,
}

bool _hasNetworkInterface(List<ConnectivityResult> results) {
  return results.any((r) => r != ConnectivityResult.none);
}

class ConnectivityNotifier extends Notifier<ConnectionStatus> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _heartbeatTimer;

  @override
  ConnectionStatus build() {
    final connectivity = Connectivity();

    _checkFullConnectivity();

    _sub = connectivity.onConnectivityChanged.listen((results) {
      if (!_hasNetworkInterface(results)) {
        state = ConnectionStatus.offline;
      } else {
        _verifyServerReachability();
      }
    });

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkFullConnectivity(),
    );

    ref.onDispose(() {
      _sub?.cancel();
      _heartbeatTimer?.cancel();
    });

    return ConnectionStatus.online;
  }

  Future<void> _checkFullConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!_hasNetworkInterface(results)) {
      state = ConnectionStatus.offline;
      return;
    }
    await _verifyServerReachability();
  }

  Future<bool> _verifyServerReachability() async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 500) {
        state = ConnectionStatus.online;
        return true;
      } else {
        state = ConnectionStatus.serverUnreachable;
        return false;
      }
    } catch (_) {
      state = ConnectionStatus.serverUnreachable;
      return false;
    }
  }

  void reportRequestResult({required bool reachable}) {
    if (reachable) {
      if (state != ConnectionStatus.online) {
        state = ConnectionStatus.online;
      }
    } else if (state == ConnectionStatus.online) {
      _checkFullConnectivity();
    }
  }

  Future<bool> checkNow() async {
    await _checkFullConnectivity();
    return state == ConnectionStatus.online;
  }
}

final connectionStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectionStatus>(
  ConnectivityNotifier.new,
);

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectionStatusProvider) == ConnectionStatus.online;
});
