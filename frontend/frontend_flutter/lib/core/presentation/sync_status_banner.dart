import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/classrooms/providers/classroom_provider.dart';
import '../../features/curriculum/providers/curriculum_provider.dart';
import '../../features/forums/providers/forum_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/sync_status_provider.dart';

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  Future<void> _triggerSyncAndRefresh(WidgetRef ref, bool hasFailures) async {
    if (hasFailures) {
      await ref.read(syncStatusProvider.notifier).retryFailed();
    } else {
      await ref.read(syncStatusProvider.notifier).syncNow();
    }
    ref.read(lessonPlansProvider.notifier).refresh();
    ref.read(classroomsProvider.notifier).refresh();
    ref.read(forumsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(connectivityStreamProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;

    if (isOnline &&
        !syncState.isSyncing &&
        !syncState.hasPending &&
        !syncState.hasFailures) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color fgColor;
    IconData icon;
    String message;

    if (!isOnline) {
      bgColor = scheme.surfaceContainerHighest;
      fgColor = scheme.onSurfaceVariant;
      icon = Icons.cloud_off_outlined;
      message = syncState.hasPending
          ? 'Offline mode • ${syncState.pendingCount} change(s) queued'
          : 'Offline mode • Working from local cache';
    } else if (syncState.isSyncing) {
      bgColor = scheme.primaryContainer;
      fgColor = scheme.onPrimaryContainer;
      icon = Icons.sync;
      message = 'Syncing offline changes...';
    } else if (syncState.hasFailures) {
      bgColor = scheme.errorContainer;
      fgColor = scheme.onErrorContainer;
      icon = Icons.error_outline;
      message =
          '${syncState.failedCount} item(s) failed to sync (${syncState.pendingCount} pending)';
    } else {
      bgColor = scheme.tertiaryContainer;
      fgColor = scheme.onTertiaryContainer;
      icon = Icons.cloud_upload_outlined;
      message = '${syncState.pendingCount} change(s) ready to sync';
    }

    return Material(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isOnline && !syncState.isSyncing)
              TextButton(
                onPressed: () =>
                    _triggerSyncAndRefresh(ref, syncState.hasFailures),
                style: TextButton.styleFrom(
                  foregroundColor: fgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                ),
                child: Text(syncState.hasFailures ? 'Retry' : 'Sync Now'),
              ),
          ],
        ),
      ),
    );
  }
}
