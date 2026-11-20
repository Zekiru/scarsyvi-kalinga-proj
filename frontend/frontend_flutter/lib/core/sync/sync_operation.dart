import 'dart:convert';
import 'package:hive/hive.dart';

part 'sync_operation.g.dart';

@HiveType(typeId: 0)
enum SyncOpStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  syncing,

  @HiveField(2)
  failedNeedsReview,
}

@HiveType(typeId: 1)
class SyncOperation extends HiveObject {
  SyncOperation({
    required this.id,
    required this.entityType,
    required this.method,
    required this.endpoint,
    this.payloadJson,
    this.tempClientId,
    this.primaryKeyField,
    this.dependsOnTempIds = const [],
    this.status = SyncOpStatus.pending,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
  });

  /// Unique client-generated ID for this queued operation.
  @HiveField(0)
  final String id;

  /// Logical model tag: e.g., 'lesson_plan', 'lesson_grade_level', 'attendance', 'grades', 'thread', 'post'.
  @HiveField(1)
  final String entityType;

  /// HTTP method: 'POST', 'PATCH', 'PUT', or 'DELETE'.
  @HiveField(2)
  final String method;

  /// Relative API path (may contain `temp_*` placeholders, e.g. `/curriculum/lesson-plans/temp_lp_1/`).
  @HiveField(3)
  final String endpoint;

  /// JSON-encoded request body (may contain `temp_*` placeholders).
  @HiveField(4)
  final String? payloadJson;

  /// If this operation creates a parent entity offline (e.g. `temp_lp_1`), store its placeholder here.
  @HiveField(5)
  final String? tempClientId;

  /// JSON key in the 201 response holding the new server PK (e.g. `'lp_id'`, `'classroom_id'`, `'thread_id'`, `'id'`).
  @HiveField(6)
  final String? primaryKeyField;

  /// Temporary IDs that MUST be resolved to real server PKs before this operation can execute.
  @HiveField(7)
  final List<String> dependsOnTempIds;

  @HiveField(8)
  SyncOpStatus status;

  @HiveField(9)
  String? errorMessage;

  @HiveField(10)
  int retryCount;

  @HiveField(11)
  final DateTime createdAt;

  Map<String, dynamic>? get decodedPayload {
    if (payloadJson == null || payloadJson!.isEmpty) return null;
    return jsonDecode(payloadJson!) as Map<String, dynamic>;
  }
}
