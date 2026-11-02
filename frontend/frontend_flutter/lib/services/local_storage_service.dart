import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/attendance_model.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';

/// A change made while offline, waiting to be sent to the server.
/// Stored as a JSON string, so it needs no Hive adapter.
class PendingOp {
  const PendingOp({
    this.key,
    required this.owner,
    required this.type,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
  });

  final int? key; // Hive key (auto-incremented, so keys are in creation order)
  final String owner; // username that made the change
  final String type; // 'attendance' | 'grades' | 'create_classroom'
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;

  String encode() => jsonEncode({
        'owner': owner,
        'type': type,
        'method': method,
        'path': path,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      });

  factory PendingOp.decode(int key, String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return PendingOp(
      key: key,
      owner: map['owner'] as String,
      type: map['type'] as String,
      method: map['method'] as String,
      path: map['path'] as String,
      body: Map<String, dynamic>.from(map['body'] as Map),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class LocalStorageService {
  // Cache boxes: disposable copies of what the server has.
  final Box<ClassroomModel> _classroomBox =
      Hive.box<ClassroomModel>('classrooms_box');
  final Box<LessonPlanModel> _lessonPlanBox =
      Hive.box<LessonPlanModel>('lesson_plans_box');
  final Box<AttendanceSessionModel> _attendanceBox =
      Hive.box<AttendanceSessionModel>('attendance_box');

  // Pending changes that have NOT reached the server yet. Never wiped by cache
  // refreshes or logout.
  final Box<String> _pendingBox = Hive.box<String>('pending_ops_box');

  /// Writes the new items first, then removes entries that are no longer on
  /// the server, so the cache is never empty midway (unlike clear + putAll).
  Future<void> _replaceAll<V>(Box<V> box, Map<dynamic, V> items) async {
    await box.putAll(items);
    final stale = box.keys.where((k) => !items.containsKey(k)).toList();
    await box.deleteAll(stale);
  }

  // ==========================================
  // CLASSROOMS
  // ==========================================
  List<ClassroomModel> getCachedClassrooms() {
    return _classroomBox.values.toList();
  }

  /// Only server-backed classrooms (with an id) belong in the cache.
  /// Classrooms created offline live in the pending queue instead.
  Future<void> cacheClassrooms(List<ClassroomModel> classrooms) async {
    await _replaceAll<ClassroomModel>(_classroomBox, <dynamic, ClassroomModel>{
      for (final c in classrooms)
        if (c.classroomId != null) c.classroomId!: c,
    });
  }

  Future<void> saveClassroom(ClassroomModel classroom) async {
    final id = classroom.classroomId;
    if (id == null) return; // drafts are handled by the pending queue
    await _classroomBox.put(id, classroom);
  }

  // ==========================================
  // LESSON PLANS
  // ==========================================
  List<LessonPlanModel> getCachedLessonPlans() {
    return _lessonPlanBox.values.toList();
  }

  Future<void> cacheLessonPlans(List<LessonPlanModel> plans) async {
    await _replaceAll<LessonPlanModel>(_lessonPlanBox, <dynamic, LessonPlanModel>{
      for (final p in plans)
        if (p.lpId != null) p.lpId!: p,
    });
  }

  Future<void> saveLessonPlan(LessonPlanModel plan) async {
    final id = plan.lpId;
    if (id == null) return;
    await _lessonPlanBox.put(id, plan);
  }

  // ==========================================
  // ATTENDANCE SESSIONS
  // ==========================================

  /// Stable key: one session per classroom per date (matches the server's
  /// unique constraint), so saving twice never creates duplicates.
  String _attendanceKey(AttendanceSessionModel s) =>
      '${s.classroomId ?? 'local'}_${s.date}';

  List<AttendanceSessionModel> getCachedAttendanceSessions() {
    return _attendanceBox.values.toList();
  }

  Future<void> cacheAttendanceSessions(
      List<AttendanceSessionModel> sessions) async {
    await _replaceAll<AttendanceSessionModel>(
      _attendanceBox,
      <dynamic, AttendanceSessionModel>{
        for (final s in sessions) _attendanceKey(s): s,
      },
    );
  }

  Future<void> saveAttendanceSession(AttendanceSessionModel session) async {
    await _attendanceBox.put(_attendanceKey(session), session);
  }

  // ==========================================
  // PENDING OFFLINE CHANGES
  // ==========================================
  Future<void> addPendingOp(PendingOp op) async {
    await _pendingBox.add(op.encode());
  }

  /// Pending changes in the order they were made, optionally for one user.
  List<PendingOp> getPendingOps({String? owner}) {
    final keys = _pendingBox.keys.whereType<int>().toList()..sort();
    final ops = <PendingOp>[];
    for (final key in keys) {
      final raw = _pendingBox.get(key);
      if (raw == null) continue;
      try {
        final op = PendingOp.decode(key, raw);
        if (owner == null || op.owner == owner) ops.add(op);
      } catch (_) {
        // Corrupt entry: skip it rather than crash the whole sync.
      }
    }
    return ops;
  }

  Future<void> removePendingOp(int key) async {
    await _pendingBox.delete(key);
  }

  int get pendingCount => _pendingBox.length;

  // ==========================================
  // UTILS
  // ==========================================

  /// Clears the cached server data only. The pending queue is intentionally
  /// kept so unsynced work survives logout.
  Future<void> clearAllCache() async {
    await Future.wait([
      _classroomBox.clear(),
      _lessonPlanBox.clear(),
      _attendanceBox.clear(),
    ]);
  }
}
