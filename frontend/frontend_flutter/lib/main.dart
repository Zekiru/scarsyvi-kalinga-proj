import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ProjectKalingaApp(),
    ),
  );
}

class ProjectKalingaApp extends ConsumerWidget {
  const ProjectKalingaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Project Kalinga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (isAuthenticated) {
          if (isAuthenticated) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}
