import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/connectivity_provider.dart';
import 'core/storage/hive_boxes.dart';
import 'core/sync/sync_status_provider.dart';
import 'features/accounts/presentation/login_screen.dart';
import 'features/accounts/presentation/profile_screen.dart';
import 'features/accounts/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (IndexedDB on Web, path_provider on Mobile/Desktop)
  // and register Phase 2 sync adapters before opening boxes.
  await HiveBoxes.init();
  await HiveBoxes.openAll();

  runApp(
    const ProviderScope(
      child: KalingaApp(),
    ),
  );
}

class KalingaApp extends ConsumerWidget {
  const KalingaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Kalinga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: switch (authState.status) {
        AuthStatus.initializing => const _SplashScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.authenticated => const _AuthenticatedShell(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Kalinga...'),
          ],
        ),
      ),
    );
  }
}

/// Temporary shell for Phase 3 testing; will expand in Phase 7 with bottom/rail navigation
/// for Curriculum, Classrooms, Forums, and Profile.
class _AuthenticatedShell extends ConsumerWidget {
  const _AuthenticatedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalinga'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              avatar: Icon(
                isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 16,
              ),
              label: Text(
                syncState.isSyncing
                    ? 'Syncing...'
                    : isOnline
                        ? (syncState.hasPending
                            ? 'Online (${syncState.pendingCount} queued)'
                            : 'Online')
                        : 'Offline (${syncState.pendingCount} queued)',
              ),
            ),
          ),
        ],
      ),
      body: const ProfileScreen(),
    );
  }
}
