import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStatusProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '@${user.username} • ${user.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Chip(label: Text(user.role.apiValue)),
                if (user.school.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('School: ${user.school}'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Offline Sync Queue'),
            subtitle: Text(
              '${syncState.pendingCount} pending • ${syncState.failedCount} needing review',
            ),
            trailing: TextButton(
              onPressed: syncState.isSyncing
                  ? null
                  : () => ref.read(syncStatusProvider.notifier).syncNow(),
              child: const Text('Sync Now'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out (Clears Local Cache)'),
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}
