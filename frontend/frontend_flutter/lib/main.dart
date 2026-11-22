import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/presentation/app_shell.dart';
import 'core/storage/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'features/accounts/presentation/login_screen.dart';
import 'features/accounts/providers/auth_provider.dart';
import 'features/home/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final themeMode = ref.watch(themeModeProvider);

    Widget home;
    switch (authState.status) {
      case AuthStatus.initializing:
        home = const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        home = const AppShell();
      case AuthStatus.unauthenticated:
        home = const LoginScreen();
    }

    return MaterialApp(
      title: 'MileBeyond Education',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routes: {
        '/home': (_) => const HomeScreen(),
      },
      home: home,
    );
  }
}
