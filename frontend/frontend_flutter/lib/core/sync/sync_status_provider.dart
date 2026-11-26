import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_prefetch_service.dart';

import '../../features/classrooms/providers/classroom_provider.dart';
import '../../features/curriculum/providers/curriculum_provider.dart';
import '../../features/forums/providers/forum_provider.dart';
import '../network/connectivity_provider.dart';
import 'sync_operation.dart';
import 'sync_queue_service.dart';

class SyncStatusState {
  const SyncStatusState({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.failedOperations = const [],
  });

  final int pendingCount;
  final int failedCount;
  final bool isSyncing;
  final List<SyncOperation> failedOperations;

  bool get hasPending => pendingCount > 0;
  bool get hasFailures => failedCount > 0;
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatusState>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatusState> {
  @override
  SyncStatusState build() {
    final queueService = ref.watch(syncQueueServiceProvider);

    // Automatically replay queued changes & refresh caches when server becomes reachable
    ref.listen<ConnectionStatus>(connectionStatusProvider, (prev, next) {
      if (prev != ConnectionStatus.online && next == ConnectionStatus.online) {
        syncNow();
      }
    });

    return _snapshot(queueService, isSyncing: false);
  }

  SyncStatusState _snapshot(
    SyncQueueService service, {
    required bool isSyncing,
  }) {
    final all = service.allOperations;
    final failed = all
        .where((op) => op.status == SyncOpStatus.failedNeedsReview)
        .toList();

    return SyncStatusState(
      pendingCount: service.pendingCount,
      failedCount: failed.length,
      isSyncing: isSyncing,
      failedOperations: failed,
    );
  }

  void refreshCounts() {
    final service = ref.read(syncQueueServiceProvider);
    state = _snapshot(service, isSyncing: state.isSyncing);
  }

  Future<void> _refreshFeatureStores() async {
    await Future.wait([
      ref.read(lessonPlansProvider.notifier).refresh(),
      ref.read(classroomsProvider.notifier).refresh(),
      ref.read(forumsProvider.notifier).refresh(),
    ]);
    ref.invalidate(participatedForumIdsProvider);
    await ref.read(offlinePrefetchServiceProvider).prefetchOwnedData();
  }

  Future<void> syncNow() async {
    final service = ref.read(syncQueueServiceProvider);
    state = _snapshot(service, isSyncing: true);

    try {
      final reachable =
          await ref.read(connectionStatusProvider.notifier).checkNow();
      if (!reachable) return;

      if (service.pendingCount > 0) {
        await service.processQueue(
          onQueueChanged: () {
            state = _snapshot(service, isSyncing: true);
          },
        );
      }
      await _refreshFeatureStores();
    } finally {
      state = _snapshot(service, isSyncing: false);
    }
  }

  Future<void> retryFailed() async {
    final service = ref.read(syncQueueServiceProvider);
    state = _snapshot(service, isSyncing: true);
    try {
      final reachable =
          await ref.read(connectionStatusProvider.notifier).checkNow();
      if (!reachable) return;

      await service.retryFailed();
      await _refreshFeatureStores();
    } finally {
      state = _snapshot(service, isSyncing: false);
    }
  }

  Future<void> discardFailedOperation(String opId) async {
    final service = ref.read(syncQueueServiceProvider);
    await service.discardOperation(opId);
    refreshCounts();
  }
}
