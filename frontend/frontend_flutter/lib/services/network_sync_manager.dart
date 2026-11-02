import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/attendance_model.dart';
import '../models/classroom_model.dart';
import '../models/student_grade_model.dart';
import 'api_service.dart';
import 'local_storage_service.dart';
import 'token_service.dart';

/// Sends changes to the server, and queues them on the device when the network
/// is down. Queued changes are replayed automatically when connectivity returns.
class NetworkSyncManager {
  NetworkSyncManager(this._api, this._local, this._tokens);

  final ApiService _api;
  final LocalStorageService _local;
  final TokenService _tokens;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  /// Called after at least one queued change was uploaded (refresh your lists).
  void Function()? onSynced;

  /// Called when the server permanently rejects a queued change (it is dropped).
  void Function(PendingOp op, ApiException error)? onRejected;

  static const attendanceType = 'attendance';
  static const gradesType = 'grades';
  static const classroomType = 'create_classroom';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void initialize() {
    _subscription?.cancel(); // avoid leaking if called twice
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (_isOnline(results)) unawaited(syncPendingData());
    });

    // The listener only fires on *changes*, so also check right now.
    Connectivity().checkConnectivity().then((results) {
      if (_isOnline(results)) unawaited(syncPendingData());
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  // ---------------------------------------------------------------------------
  // Send now, or queue for later
  // ---------------------------------------------------------------------------

  /// Tries to send the request. Returns true if the server accepted it, or
  /// false if it was queued because the network/server was unreachable.
  /// Throws [ApiException] if the server rejected it (validation error, 401...):
  /// retrying can't help, so those are never queued.
  Future<bool> sendOrQueue({
    required String type,
    required String method,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    try {
      await _api.sendRaw(method, path, body);
      return true;
    } on ApiException catch (e) {
      if (e.isClientError) rethrow;
      await _enqueue(type, method, path, body); // 5xx: server asleep/erroring
      return false;
    } catch (_) {
      await _enqueue(type, method, path, body); // timeout / no connection
      return false;
    }
  }

  Future<void> _enqueue(
    String type,
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    await _local.addPendingOp(PendingOp(
      owner: await _owner(),
      type: type,
      method: method,
      path: path,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  Future<String> _owner() async => await _tokens.getUsername() ?? 'unknown';

  // Convenience wrappers: use these from screens/providers instead of ApiService.

  Future<bool> submitAttendance(int classroomId, AttendanceSessionModel session) =>
      sendOrQueue(
        type: attendanceType,
        method: 'POST',
        path: '/classrooms/$classroomId/attendance/',
        body: session.toJson(),
      );

  Future<bool> submitGrades(int classroomId, StudentGradeBatchPayload payload) =>
      sendOrQueue(
        type: gradesType,
        method: 'POST',
        path: '/classrooms/$classroomId/grades/',
        body: payload.toJson(),
      );

  Future<bool> createClassroom(ClassroomModel classroom) => sendOrQueue(
        type: classroomType,
        method: 'POST',
        path: '/classrooms/',
        body: classroom.toWriteJson(),
      );

  /// Classrooms created offline that haven't been uploaded yet (for display).
  Future<List<ClassroomModel>> pendingClassroomDrafts() async {
    final ops = _local.getPendingOps(owner: await _owner());
    final drafts = <ClassroomModel>[];
    for (final op in ops.where((o) => o.type == classroomType)) {
      try {
        drafts.add(ClassroomModel.fromJson(op.body));
      } catch (_) {}
    }
    return drafts;
  }

  // ---------------------------------------------------------------------------
  // Replay the queue
  // ---------------------------------------------------------------------------

  Future<void> syncPendingData() async {
    if (_isSyncing) return; // connectivity events often fire several times
    _isSyncing = true;
    try {
      final token = await _tokens.getToken();
      if (token == null) return; // not logged in: leave the queue alone

      var uploadedAny = false;

      // Only this user's changes, oldest first.
      for (final op in _local.getPendingOps(owner: await _owner())) {
        try {
          await _api.sendRaw(op.method, op.path, op.body);
          await _local.removePendingOp(op.key!);
          uploadedAny = true;
        } on ApiException catch (e) {
          if (e.statusCode == 401) break; // session expired: keep the queue
          if (e.isClientError) {
            // Server will never accept this one (e.g. student was removed).
            await _local.removePendingOp(op.key!);
            onRejected?.call(op, e);
            continue;
          }
          break; // 5xx: server not ready, retry on the next trigger
        } catch (_) {
          break; // offline / timeout: keep everything, retry later
        }
      }

      if (uploadedAny) onSynced?.call();
    } finally {
      _isSyncing = false;
    }
  }
}
