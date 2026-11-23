import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _hasNetwork(List<ConnectivityResult> results) {
  return results.any((r) => r != ConnectivityResult.none);
}

final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Emit initial state immediately
  final initial = await connectivity.checkConnectivity();
  yield _hasNetwork(initial);

  // Emit subsequent connectivity transitions
  await for (final results in connectivity.onConnectivityChanged) {
    yield _hasNetwork(results);
  }
});

/// Synchronous convenience provider defaulting to `true` until first check resolves.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});
