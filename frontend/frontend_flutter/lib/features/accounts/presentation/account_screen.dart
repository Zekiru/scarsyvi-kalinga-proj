import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStatusProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    final isOnline = connectionStatus == ConnectionStatus.online;
    final canAttemptSync =
        !syncState.isSyncing && connectionStatus != ConnectionStatus.offline;

    final (IconData syncIcon, Color syncIconColor, String statusLabel) =
        switch (connectionStatus) {
      ConnectionStatus.online => (
          Icons.cloud_done_outlined,
          scheme.primary,
          'Online',
        ),
      ConnectionStatus.serverUnreachable => (
          Icons.cloud_off_outlined,
          scheme.error,
          'Connection Failed (Server Unreachable)',
        ),
      ConnectionStatus.offline => (
          Icons.wifi_off_outlined,
          scheme.error,
          'Offline (No Internet)',
        ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}${user.email.isNotEmpty ? ' • ${user.email}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (user.school.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user.school,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(user.role.apiValue),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text(
                  'Role Capabilities',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: Icon(
                  user.canTeach ? Icons.check_circle : Icons.cancel_outlined,
                ),
                title: const Text('Classroom & Curriculum Authoring'),
                subtitle: const Text(
                  'Manage rosters, attendance, grades, and lesson plans',
                ),
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  user.canModerate ? Icons.check_circle : Icons.cancel_outlined,
                ),
                title: const Text('Checker & Forum Moderation'),
                subtitle: const Text(
                  'Approve lesson plans, lock forums, pin/hide threads & posts',
                ),
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  user.canAdminister
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                ),
                title: const Text('System Administration'),
                subtitle: const Text(
                  'Assign checkers and administer platform accounts',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(syncIcon, color: syncIconColor),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Offline Sync Engine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: !canAttemptSync
                              ? null
                              : () {
                                  if (syncState.hasFailures) {
                                    ref
                                        .read(syncStatusProvider.notifier)
                                        .retryFailed();
                                  } else {
                                    ref
                                        .read(syncStatusProvider.notifier)
                                        .syncNow();
                                  }
                                },
                          icon: const Icon(Icons.sync, size: 18),
                          label: Text(
                            !isOnline || syncState.hasFailures
                                ? 'Retry'
                                : 'Sync',
                          ),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: $statusLabel • '
                      'Pending: ${syncState.pendingCount} • '
                      'Failed: ${syncState.failedCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (syncState.failedOperations.isNotEmpty) ...[
                const Divider(height: 1),
                for (final op in syncState.failedOperations)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(
                      '${op.method} ${op.endpoint}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      op.errorMessage ??
                          '${op.entityType} • Failed after ${op.retryCount} retries',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Discard failed item',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(syncStatusProvider.notifier)
                          .discardFailedOperation(op.id),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}
