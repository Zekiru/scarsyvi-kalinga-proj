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

          final response = await _dispatch(
            method: op.method,
            endpoint: resolvedEndpoint,
            body: resolvedPayload,
          );

          // Record newly created server PK if this operation created a parent record
          if (op.tempClientId != null &&
              op.primaryKeyField != null &&
              response is Map<String, dynamic>) {
            final newId = response[op.primaryKeyField];
            if (newId is int) {
              await _idMappings.saveMapping(op.tempClientId!, newId);
            }
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
            // Retry hit an already-created unique record (e.g. LessonGradeLevel or StudentGrade)
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
    } finally {
      _isProcessing = false;
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
