import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/presentation/account_screen.dart';
import '../../features/classrooms/presentation/classrooms_screen.dart';
import '../../features/curriculum/presentation/lesson_plans_screen.dart';
import '../../features/forums/presentation/forums_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../network/connectivity_provider.dart';
import '../sync/offline_prefetch_service.dart';
import '../sync/sync_status_provider.dart';
import 'sync_status_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycleListener;
  DateTime? _lastResumeSync;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(offlinePrefetchServiceProvider).prefetchOwnedData();
    });

    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        final now = DateTime.now();
        // Throttle to at most once every 15 seconds on rapid app switches
        if (_lastResumeSync == null ||
            now.difference(_lastResumeSync!) > const Duration(seconds: 15)) {
          _lastResumeSync = now;
          ref.read(syncStatusProvider.notifier).syncNow();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;

  static const _titles = [
    'Home',
    'Curriculum',
    'Classrooms',
    'Community Forums',
    'Account & Sync',
  ];

  void _selectTab(int index) {
    if (index >= 0 && index < _titles.length) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final scheme = Theme.of(context).colorScheme;

    final (IconData statusIcon, Color statusColor, String statusTooltip) =
        switch (connectionStatus) {
      ConnectionStatus.online => (
          Icons.wifi_outlined,
          scheme.primary,
          'Online • Connected to server',
        ),
      ConnectionStatus.serverUnreachable => (
          Icons.cloud_off_outlined,
          scheme.error,
          'Connection failed • Server unreachable',
        ),
      ConnectionStatus.offline => (
          Icons.wifi_off_outlined,
          scheme.error,
          'Offline • No internet connection',
        ),
    };

    final pages = <Widget>[
      HomeScreen(onNavigateToTab: _selectTab),
      const LessonPlansScreen(),
      const ClassroomsScreen(),
      const ForumsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: statusTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    ref.read(connectionStatusProvider.notifier).checkNow(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    statusIcon,
                    size: 20,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('Curriculum'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.class_outlined),
                        selectedIcon: Icon(Icons.class_),
                        label: Text('Classrooms'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.forum_outlined),
                        selectedIcon: Icon(Icons.forum),
                        label: Text('Forums'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Account'),
                      ),
                    ],
                  ),
                if (isWide) const VerticalDivider(width: 1),
                Expanded(
                  child: pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Curriculum',
                ),
                NavigationDestination(
                  icon: Icon(Icons.class_outlined),
                  selectedIcon: Icon(Icons.class_),
                  label: 'Classes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum),
                  label: 'Forums',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            ),
    );
  }
}
