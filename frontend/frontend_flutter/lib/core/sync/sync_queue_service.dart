import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/hive_boxes.dart';
import 'id_mapping_store.dart';
import 'sync_operation.dart';

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService(
    apiClient: ref.watch(apiClientProvider),
    idMappings: ref.watch(idMappingStoreProvider),
    queueBox: HiveBoxes.queue,
  );
});

class SyncQueueService {
  SyncQueueService({
    required this._apiClient,
    required this._idMappings,
    required this._queueBox,
  });

  final ApiClient _apiClient;
  final IdMappingStore _idMappings;
  final Box<SyncOperation> _queueBox;

  bool _isProcessing = false;

  List<SyncOperation> get allOperations {
    final items = _queueBox.values.toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  int get pendingCount => allOperations
      .where((op) =>
          op.status == SyncOpStatus.pending ||
          op.status == SyncOpStatus.syncing)
      .length;

  int get failedCount => allOperations
      .where((op) => op.status == SyncOpStatus.failedNeedsReview)
      .length;

  bool get hasActiveOperations => allOperations.isNotEmpty;

  /// Returns true if an operation for [tempClientId] or [entityType] is still
  /// queued or awaiting user review.
  bool isEntityQueued({String? tempClientId, String? entityType}) {
    for (final op in allOperations) {
      if (tempClientId != null && op.tempClientId == tempClientId) {
        return true;
      }
      if (entityType != null && op.entityType == entityType) {
        return true;
      }
    }
    return false;
  }

  Future<String?> _checkRemoteConflict({
    required String endpoint,
    required DateTime queuedAt,
  }) async {
    try {
      final current = await _apiClient.get(endpoint);
      if (current is Map<String, dynamic>) {
        final rawUpdated =
            current['updated_at'] ?? current['modified_at'] ?? current['updated'];
        if (rawUpdated is String) {
          final remoteUpdatedAt = DateTime.tryParse(rawUpdated)?.toUtc();
          // 5-second grace buffer for minor device clock skew
          if (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(
                queuedAt.toUtc().add(const Duration(seconds: 5)),
              )) {
            return 'Modified on server by another user while offline. '
                'Tap Retry to overwrite or Discard to keep server version.';
          }
        }
      }
    } on ApiException catch (e) {
      if (e.isOffline) rethrow;
      if (e.statusCode == 404) {
        return 'Record was deleted on the server while you were offline.';
      }
    } catch (_) {}
    return null;
  }

  /// Enqueues an offline mutation into Hive.
  Future<SyncOperation> enqueue({
    required String entityType,
    required String method,
    required String endpoint,
    Map<String, dynamic>? payload,
    String? tempClientId,
    String? primaryKeyField,
    List<String> dependsOnTempIds = const [],
  }) async {
    final op = SyncOperation(
      id: '${DateTime.now().microsecondsSinceEpoch}_$entityType',
      entityType: entityType,
      method: method.toUpperCase(),
      endpoint: endpoint,
      payloadJson: payload != null ? jsonEncode(payload) : null,
      tempClientId: tempClientId,
      primaryKeyField: primaryKeyField,
      dependsOnTempIds: dependsOnTempIds,
      createdAt: DateTime.now(),
    );

    await _queueBox.put(op.id, op);
    return op;
  }

  /// Replays all pending operations in strict FIFO order.
  /// Stops early if the device goes back offline.
  Future<void> processQueue({void Function()? onQueueChanged}) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final ops = allOperations
          .where((op) => op.status == SyncOpStatus.pending)
          .toList();

      for (final op in ops) {
        // Verify all parent temp IDs have been mapped to real server PKs
        final unresolvedDeps = op.dependsOnTempIds
            .where((dep) => !_idMappings.hasMapping(dep))
            .toList();

        if (unresolvedDeps.isNotEmpty) {
          op.status = SyncOpStatus.failedNeedsReview;
          op.errorMessage =
              'Blocked by un-synced parent record(s): ${unresolvedDeps.join(', ')}';
          await op.save();
          onQueueChanged?.call();
          continue;
        }

        op.status = SyncOpStatus.syncing;
        await op.save();
        onQueueChanged?.call();

        try {
          final resolvedEndpoint = _idMappings.resolveEndpoint(op.endpoint);
          final rawPayload = op.decodedPayload;
          final resolvedPayload = rawPayload != null
              ? _idMappings.resolvePayload(rawPayload)
              : null;

          // Conflict check for offline edits (PATCH/PUT) before overwriting
          if ((op.method == 'PATCH' || op.method == 'PUT') &&
              !resolvedEndpoint.contains(IdMappingStore.tempPrefix)) {
            final conflictMsg = await _checkRemoteConflict(
              endpoint: resolvedEndpoint,
              queuedAt: op.createdAt,
            );
            if (conflictMsg != null) {
              op.status = SyncOpStatus.failedNeedsReview;
              op.errorMessage = conflictMsg;
              await op.save();
              onQueueChanged?.call();
              continue;
            }
          }

          final response = await _dispatch(
            method: op.method,
            endpoint: resolvedEndpoint,
            body: resolvedPayload,
          );

          // Record newly created server PK and reconcile local Hive caches
          if (op.tempClientId != null) {
            int? parsedId;
            if (op.primaryKeyField != null &&
                response is Map<String, dynamic>) {
              final newId = response[op.primaryKeyField] ?? response['id'];
              parsedId =
                  newId is int ? newId : int.tryParse(newId?.toString() ?? '');
            }
            if (parsedId != null) {
              await _idMappings.saveMapping(op.tempClientId!, parsedId);
            }
            await _reconcileLocalCacheAfterCreate(op.tempClientId!, parsedId);
          }

          await op.delete();
          onQueueChanged?.call();
        } on ApiException catch (e) {
          if (e.isOffline) {
            // Restore pending status and pause queue until connectivity returns
            op.status = SyncOpStatus.pending;
            await op.save();
            onQueueChanged?.call();
            break;
          }

          if (e.isUniqueConstraintCollision) {
            if (op.tempClientId != null) {
              await _reconcileLocalCacheAfterCreate(op.tempClientId!, null);
            }
            await op.delete();
            onQueueChanged?.call();
            continue;
          }

          // 400 validation, 403 locked forum/RBAC, or 404 deleted parent:
          // Isolate as failedNeedsReview so subsequent independent items can still sync.
          op.status = SyncOpStatus.failedNeedsReview;
          op.errorMessage = e.message;
          op.retryCount += 1;
          await op.save();
          onQueueChanged?.call();
        }
      }

      // If all queued operations have drained, clear any remaining optimistic
      // `isPendingSync` flags across Hive caches (e.g., from offline PATCH edits).
      if (!hasActiveOperations) {
        await clearAllPendingSyncFlags();
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Universally clears `"isPendingSync":true` flags and orphaned `temp_*`
  /// list items across all feature Hive boxes once the sync queue is empty.
  Future<void> clearAllPendingSyncFlags() async {
    final boxes = <Box<String>>[
      HiveBoxes.curriculum,
      HiveBoxes.classrooms,
      HiveBoxes.forums,
    ];

    for (final box in boxes) {
      if (!box.isOpen) continue;
      final keysToDelete = <dynamic>[];
      final updates = <dynamic, String>{};

      for (final key in box.keys) {
        final keyStr = key.toString();
        if (keyStr.contains(IdMappingStore.tempPrefix)) {
          keysToDelete.add(key);
          continue;
        }
        final raw = box.get(key);
        if (raw == null) continue;
        if (!raw.contains('"isPendingSync":true') &&
            !raw.contains(IdMappingStore.tempPrefix)) {
          continue;
        }

        var cleaned =
            raw.replaceAll('"isPendingSync":true', '"isPendingSync":false');
        try {
          final decoded = jsonDecode(cleaned);
          if (decoded is List) {
            final filtered = decoded.where((entry) {
              if (entry is Map) {
                final idVal = entry['id']?.toString() ?? '';
                if (idVal.startsWith(IdMappingStore.tempPrefix)) return false;
              }
              return true;
            }).toList();
            cleaned = jsonEncode(filtered);
          }
        } catch (_) {}
        updates[key] = cleaned;
      }

      for (final k in keysToDelete) {
        await box.delete(k);
      }
      for (final entry in updates.entries) {
        await box.put(entry.key, entry.value);
      }
    }
  }

  /// Removes synced `temp_*` draft entries from list caches and rewrites any
  /// remaining `temp_*` references across feature Hive boxes.
  Future<void> _reconcileLocalCacheAfterCreate(
    String tempClientId,
    int? serverId,
  ) async {
    final boxes = <Box<String>>[
      HiveBoxes.curriculum,
      HiveBoxes.classrooms,
      HiveBoxes.forums,
    ];

    for (final box in boxes) {
      if (!box.isOpen) continue;
      final keysToDelete = <dynamic>[];
      final updates = <dynamic, String>{};

      for (final key in box.keys) {
        final keyStr = key.toString();
        final raw = box.get(key);
        if (raw == null) continue;

        if (keyStr.endsWith('_$tempClientId')) {
          keysToDelete.add(key);
          continue;
        }

        if (!raw.contains(tempClientId)) continue;

        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final filtered = decoded.where((entry) {
              if (entry is Map) {
                final idVal = entry['id']?.toString() ?? '';
                if (idVal == tempClientId) return false;
              }
              return true;
            }).toList();
            var encoded = jsonEncode(filtered);
            if (serverId != null) {
              encoded = encoded.replaceAll('"$tempClientId"', '$serverId');
            }
            updates[key] = encoded;
          } else if (serverId != null) {
            updates[key] = raw.replaceAll('"$tempClientId"', '$serverId');
          }
        } catch (_) {
          if (serverId != null) {
            updates[key] = raw.replaceAll(tempClientId, '$serverId');
          }
        }
      }

      for (final k in keysToDelete) {
        await box.delete(k);
      }
      for (final entry in updates.entries) {
        await box.put(entry.key, entry.value);
      }
    }
  }

  Future<void> retryFailed() async {
    for (final op in allOperations) {
      if (op.status == SyncOpStatus.failedNeedsReview) {
        op.status = SyncOpStatus.pending;
        op.errorMessage = null;
        await op.save();
      }
    }
    await processQueue();
  }

  Future<void> discardOperation(String opId) async {
    final op = _queueBox.get(opId);
    if (op?.tempClientId != null) {
      await _reconcileLocalCacheAfterCreate(op!.tempClientId!, null);
    }
    await _queueBox.delete(opId);
  }

  Future<dynamic> _dispatch({
    required String method,
    required String endpoint,
    dynamic body,
  }) {
    switch (method) {
      case 'POST':
        return _apiClient.post(endpoint, body: body);
      case 'PATCH':
        return _apiClient.patch(endpoint, body: body);
      case 'PUT':
        return _apiClient.put(endpoint, body: body);
      case 'DELETE':
        return _apiClient.delete(endpoint);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }
}
