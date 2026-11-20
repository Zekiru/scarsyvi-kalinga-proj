import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/sync/sync_status_provider.dart';
import '../providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(connectivityStreamProvider).value ?? true;

    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '@${user.username}${user.email.isNotEmpty ? ' • ${user.email}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (user.school.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user.school,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(label: Text(user.role.apiValue)),
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
              ListTile(
                leading: Icon(
                  isOnline
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                ),
                title: const Text(
                  'Offline Sync Engine',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Status: ${isOnline ? 'Online' : 'Offline'} • '
                  'Pending: ${syncState.pendingCount} • '
                  'Failed: ${syncState.failedCount}',
                ),
                trailing: FilledButton.tonalIcon(
                  onPressed: (!isOnline || syncState.isSyncing)
                      ? null
                      : () {
                          if (syncState.hasFailures) {
                            ref.read(syncStatusProvider.notifier).retryFailed();
                          } else {
                            ref.read(syncStatusProvider.notifier).syncNow();
                          }
                        },
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(syncState.hasFailures ? 'Retry' : 'Sync'),
                ),
              ),
              if (syncState.failedOperations.isNotEmpty) ...[
                const Divider(height: 1),
                for (final op in syncState.failedOperations)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text('${op.method} ${op.endpoint}'),
                    subtitle: Text(
                      op.errorMessage ??
                          '${op.entityType} • Failed after ${op.retryCount} retries',
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
