import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/sync/id_mapping_store.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../curriculum/data/models/json_parsers.dart';
import 'classroom_models.dart';

typedef JsonMap = Map<String, dynamic>;

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepository(
    apiClient: ref.watch(apiClientProvider),
    syncQueue: ref.watch(syncQueueServiceProvider),
    cacheBox: HiveBoxes.classrooms,
  );
});

class ClassroomRepository {
  ClassroomRepository({
    required this._apiClient,
    required this._syncQueue,
    required this._cacheBox,
  });

  final ApiClient _apiClient;
  final SyncQueueService _syncQueue;
  final Box<String> _cacheBox;

  static const String _classroomsKey = 'classrooms_list';
  static const String _masterStudentsKey = 'master_students_list';
  static String _classroomDetailKey(String id) => 'classroom_$id';
  static String _classroomStudentsKey(String id, String ordering) =>
      'classroom_students_${id}_$ordering';
  static String _attendanceSessionsKey(String classroomId) =>
      'attendance_sessions_$classroomId';
  static String _gradesKey(String classroomId) => 'grades_$classroomId';

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map) {
      if (response['results'] is List) return response['results'] as List<dynamic>;
      if (response['data'] is List) return response['data'] as List<dynamic>;
      for (final val in response.values) {
        if (val is List) return val;
      }
    }
    return const [];
  }

  Future<List<dynamic>> _fetchAllItems(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    final items = <dynamic>[];
    String? nextUrl = endpoint;
    Map<String, dynamic>? currentParams = queryParams;

    while (nextUrl != null && nextUrl.isNotEmpty) {
      final response = await _apiClient.get(nextUrl, queryParams: currentParams);
      items.addAll(_extractList(response));

      if (response is Map && response['next'] is String) {
        final rawNext = response['next'] as String;
        final apiIdx = rawNext.indexOf('/api/v1/');
        nextUrl = apiIdx >= 0 ? rawNext.substring(apiIdx + 7) : rawNext;
        currentParams = null;
      } else {
        nextUrl = null;
      }
    }
    return items;
  }

  // ==========================================
  // CLASSROOMS & ROSTER (with Analytics & Sorting)
  // ==========================================

  Future<List<Classroom>> fetchClassrooms({String? search}) async {
    try {
      final raw = await _fetchAllItems(
        ApiEndpoints.classrooms,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final cachedById = {
        for (final c in getCachedClassrooms()) c.id: c,
      };
      final serverList = parseModelList(raw, Classroom.fromJson).map((cls) {
        final prev = cachedById[cls.id];
        if (prev != null && prev.students.isNotEmpty && cls.students.isEmpty) {
          return cls.copyWith(
            students: prev.students,
            studentCount: cls.studentCount > 0
                ? cls.studentCount
                : prev.students.length,
          );
        }
        return cls;
      }).toList();

      final unsyncedLocal =
          getCachedClassrooms().where((c) => c.isLocalDraft).toList();
      final merged = [...unsyncedLocal, ...serverList];

      await _cacheBox.put(_classroomsKey, Classroom.encodeList(merged));
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedClassrooms();
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<Classroom> getCachedClassrooms() {
    final raw = _cacheBox.get(_classroomsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return Classroom.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<Classroom> fetchClassroomDetail(String id) async {
    final serverId = int.tryParse(id);
    if (serverId == null) {
      final cached = getCachedClassroomDetail(id);
      if (cached != null) return cached;
      throw ApiException(message: 'Local draft classroom not found.');
    }

    try {
      final detailResp =
          await _apiClient.get(ApiEndpoints.classroomDetail(serverId));
      var classroom = Classroom.fromJson(
        Map<String, dynamic>.from(detailResp as Map),
      );

      final roster = await fetchClassroomStudents(id, ordering: 'last_name');
      classroom = classroom.copyWith(
        students: roster,
        studentCount: roster.length,
      );

      await _saveClassroomCache(classroom);
      return classroom;
    } on ApiException catch (e) {
      final cached = getCachedClassroomDetail(id);
      if (e.isOffline && cached != null) return cached;
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<Student>> fetchClassroomStudents(
    String classroomId, {
    String ordering = 'last_name',
    String? search,
  }) async {
    final serverId = int.tryParse(classroomId);
    if (serverId == null) {
      return getCachedClassroomDetail(classroomId)?.students ?? const [];
    }

    try {
      final raw = await _fetchAllItems(
        ApiEndpoints.classroomStudents(serverId),
        queryParams: {
          'ordering': ordering,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final serverStudents = parseModelList(raw, Student.fromJson);

      final existing = getCachedClassroomDetail(classroomId);
      final pendingLocal =
          existing?.students.where((s) => s.isPendingSync).toList() ??
              const <Student>[];

      final merged = [...pendingLocal, ...serverStudents];
      await _cacheBox.put(
        _classroomStudentsKey(classroomId, ordering),
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
      return merged;
    } on ApiException catch (e) {
      final raw = _cacheBox.get(_classroomStudentsKey(classroomId, ordering));
      if (raw != null && raw.isNotEmpty) {
        return parseModelList(jsonDecode(raw), Student.fromJson);
      }
      final fallback =
          getCachedClassroomDetail(classroomId)?.students ?? const [];
      if (e.isOffline || fallback.isNotEmpty) return fallback;
      rethrow;
    }
  }

  Classroom? getCachedClassroomDetail(String id) {
    final raw = _cacheBox.get(_classroomDetailKey(id));
    if (raw != null && raw.isNotEmpty) {
      try {
        return Classroom.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {}
    }
    return getCachedClassrooms().where((c) => c.id == id).firstOrNull;
  }

  Future<void> _saveClassroomCache(Classroom classroom) async {
    await _cacheBox.put(
      _classroomDetailKey(classroom.id),
      jsonEncode(classroom.toJson()),
    );
    final list = List<Classroom>.of(getCachedClassrooms());
    final idx = list.indexWhere((c) => c.id == classroom.id);
    if (idx >= 0) {
      list[idx] = classroom;
    } else {
      list.insert(0, classroom);
    }
    await _cacheBox.put(_classroomsKey, Classroom.encodeList(list));
  }

  Future<void> _removeClassroomCache(String id) async {
    await _cacheBox.delete(_classroomDetailKey(id));
    final list = List<Classroom>.of(getCachedClassrooms())
      ..removeWhere((c) => c.id == id);
    await _cacheBox.put(_classroomsKey, Classroom.encodeList(list));
  }

  // ==========================================
  // CREATE, UPDATE & DELETE CLASSROOM
  // ==========================================

  Future<Classroom> createClassroom({
    required String name,
    String schoolName = '',
    String section = '',
    String schoolYear = '',
    List<int> gradeLevelIds = const [],
    List<String> gradeLevelNames = const [],
    String? lessonPlanId,
    String lessonPlanTitle = '',
    int? adviserId,
    String adviserName = '',
  }) async {
    final deps = <String>[];
    final isLpTemp = lessonPlanId != null &&
        lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    if (isLpTemp) deps.add(lessonPlanId);

    final payload = <String, dynamic>{
      'name': name.trim(),
      'school_name': schoolName.trim(),
      'section': section.trim(),
      'school_year': schoolYear.trim(),
      'is_active': true,
      if (gradeLevelIds.isNotEmpty) 'grade_levels': gradeLevelIds,
      if (lessonPlanId != null && lessonPlanId.isNotEmpty)
        'lesson_plan': isLpTemp ? lessonPlanId : int.parse(lessonPlanId),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Lesson plan offline draft', isOffline: true);
      }
      final response =
          await _apiClient.post(ApiEndpoints.classrooms, body: payload);
      final created = Classroom.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      await _saveClassroomCache(created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempId = IdMappingStore.generateTempId('cls');
      final draft = Classroom(
        id: tempId,
        name: name.trim(),
        schoolName: schoolName.trim(),
        section: section.trim(),
        schoolYear: schoolYear.trim(),
        adviserId: adviserId,
        adviserName: adviserName,
        gradeLevelIds: gradeLevelIds,
        gradeLevelNames: gradeLevelNames,
        lessonPlanId: lessonPlanId,
        lessonPlanTitle: lessonPlanTitle,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'classroom',
        method: 'POST',
        endpoint: ApiEndpoints.classrooms,
        payload: payload,
        tempClientId: tempId,
        primaryKeyField: 'classroom_id',
        dependsOnTempIds: deps,
      );
      await _saveClassroomCache(draft);
      return draft;
    }
  }

  Future<Classroom> updateClassroom({
    required String classroomId,
    required String name,
    String schoolName = '',
    String section = '',
    String schoolYear = '',
    bool isActive = true,
    List<int> gradeLevelIds = const [],
    List<String> gradeLevelNames = const [],
    String? lessonPlanId,
    String lessonPlanTitle = '',
  }) async {
    final isTemp = classroomId.startsWith(IdMappingStore.tempPrefix);
    final isLpTemp = lessonPlanId != null &&
        lessonPlanId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/classrooms/classrooms/$classroomId/';

    final payload = <String, dynamic>{
      'name': name.trim(),
      'school_name': schoolName.trim(),
      'section': section.trim(),
      'school_year': schoolYear.trim(),
      'is_active': isActive,
      'grade_levels': gradeLevelIds,
      'lesson_plan': (lessonPlanId != null && lessonPlanId.isNotEmpty)
          ? (isLpTemp ? lessonPlanId : int.parse(lessonPlanId))
          : null,
    };

    try {
      if (isTemp || isLpTemp) {
        throw ApiException(message: 'Record is offline draft', isOffline: true);
      }
      await _apiClient.patch(endpoint, body: payload);
      return await fetchClassroomDetail(classroomId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'classroom_update',
        method: 'PATCH',
        endpoint: endpoint,
        payload: payload,
        dependsOnTempIds: [
          if (isTemp) classroomId,
          if (isLpTemp) lessonPlanId,
        ],
      );

      final existing = getCachedClassroomDetail(classroomId);
      if (existing != null) {
        final optimistic = existing.copyWith(
          name: name.trim(),
          schoolName: schoolName.trim(),
          section: section.trim(),
          schoolYear: schoolYear.trim(),
          isActive: isActive,
          gradeLevelIds: gradeLevelIds,
          gradeLevelNames: gradeLevelNames,
          lessonPlanId: lessonPlanId,
          clearLessonPlan: lessonPlanId == null || lessonPlanId.isEmpty,
          lessonPlanTitle: lessonPlanTitle,
          isPendingSync: true,
        );
        await _saveClassroomCache(optimistic);
        return optimistic;
      }
      rethrow;
    }
  }

  Future<void> deleteClassroom(String classroomId) async {
    final isTemp = classroomId.startsWith(IdMappingStore.tempPrefix);
    final endpoint = '/classrooms/classrooms/$classroomId/';

    try {
      if (!isTemp) {
        await _apiClient.delete(endpoint);
      }
      await _removeClassroomCache(classroomId);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'classroom_delete',
        method: 'DELETE',
        endpoint: endpoint,
        payload: const {},
        dependsOnTempIds: isTemp ? [classroomId] : const [],
      );
      await _removeClassroomCache(classroomId);
    }
  }

  // ==========================================
  // CREATE STUDENT & ENROLL
  // ==========================================

  Future<Student> createAndEnrollStudent({
    required String classroomId,
    required String firstName,
    required String lastName,
    String gender = '',
    String lrn = '',
    int? gradeLevelId,
    String gradeLevelName = '',
  }) async {
    final studentPayload = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      if (gender.isNotEmpty) 'gender': gender,
      if (lrn.trim().isNotEmpty) 'lrn': lrn.trim(),
      'grade_level': ?gradeLevelId,
    };

    final isClassTemp = classroomId.startsWith(IdMappingStore.tempPrefix);

    try {
      if (isClassTemp) {
        throw ApiException(message: 'Classroom offline draft', isOffline: true);
      }

      final stuResp =
          await _apiClient.post(ApiEndpoints.students, body: studentPayload);
      final created = Student.fromJson(
        Map<String, dynamic>.from(stuResp as Map),
      );

      await _apiClient.post(
        ApiEndpoints.classroomEnrollStudents(int.parse(classroomId)),
        body: {
          'student_ids': [int.parse(created.id)],
        },
      );

      await _appendStudentToClassroom(classroomId, created);
      return created;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      final tempStuId = IdMappingStore.generateTempId('stu');
      final draft = Student(
        id: tempStuId,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        gender: gender,
        lrn: lrn.trim(),
        gradeLevelId: gradeLevelId,
        gradeLevelName: gradeLevelName,
        isPendingSync: true,
      );

      await _syncQueue.enqueue(
        entityType: 'student',
        method: 'POST',
        endpoint: ApiEndpoints.students,
        payload: studentPayload,
        tempClientId: tempStuId,
        primaryKeyField: 'student_id',
      );

      await _syncQueue.enqueue(
        entityType: 'enroll_students',
        method: 'POST',
        endpoint: ApiEndpoints.classroomEnrollStudents(classroomId),
        payload: {
          'student_ids': [tempStuId],
        },
        dependsOnTempIds: [
          if (isClassTemp) classroomId,
          tempStuId,
        ],
      );

      await _appendStudentToClassroom(classroomId, draft);
      return draft;
    }
  }

  Future<void> enrollExistingStudents({
    required String classroomId,
    required List<Student> studentsToEnroll,
  }) async {
    if (studentsToEnroll.isEmpty) return;

    final isClassTemp = classroomId.startsWith(IdMappingStore.tempPrefix);
    final deps = <String>[
      if (isClassTemp) classroomId,
      for (final s in studentsToEnroll)
        if (s.id.startsWith(IdMappingStore.tempPrefix)) s.id,
    ];

    final payload = {
      'student_ids': studentsToEnroll
          .map((s) => s.id.startsWith(IdMappingStore.tempPrefix)
              ? s.id
              : int.parse(s.id))
          .toList(),
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }
      await _apiClient.post(
        ApiEndpoints.classroomEnrollStudents(int.parse(classroomId)),
        body: payload,
      );
      for (final s in studentsToEnroll) {
        await _appendStudentToClassroom(classroomId, s);
      }
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'enroll_students',
        method: 'POST',
        endpoint: ApiEndpoints.classroomEnrollStudents(classroomId),
        payload: payload,
        dependsOnTempIds: deps,
      );
      for (final s in studentsToEnroll) {
        await _appendStudentToClassroom(classroomId, s);
      }
    }
  }

  Future<List<Student>> fetchMasterStudents({String? search}) async {
    try {
      final raw = await _fetchAllItems(
        ApiEndpoints.students,
        queryParams: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final students = parseModelList(raw, Student.fromJson);
      if (search == null || search.trim().isEmpty) {
        await _cacheBox.put(
          _masterStudentsKey,
          jsonEncode(students.map((e) => e.toJson()).toList()),
        );
      }
      return students;
    } on ApiException catch (e) {
      final raw = _cacheBox.get(_masterStudentsKey);
      if (raw != null && raw.isNotEmpty) {
        var cached = parseModelList(jsonDecode(raw), Student.fromJson);
        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          cached = cached
              .where((s) =>
                  s.fullName.toLowerCase().contains(q) ||
                  s.lrn.toLowerCase().contains(q))
              .toList();
        }
        return cached;
      }
      if (e.isOffline) return const [];
      rethrow;
    }
  }

  Future<void> _appendStudentToClassroom(
    String classroomId,
    Student student,
  ) async {
    final existing = getCachedClassroomDetail(classroomId);
    if (existing == null) return;
    if (existing.students.any((s) => s.id == student.id)) return;
    final nextStudents = [...existing.students, student];
    final updated = existing.copyWith(
      students: nextStudents,
      studentCount: nextStudents.length,
    );
    await _saveClassroomCache(updated);
  }

  // ==========================================
  // ATTENDANCE SESSIONS (`record-attendance/`)
  // ==========================================

  Future<List<AttendanceSession>> fetchAttendanceSessions(
    String classroomId,
  ) async {
    final serverId = int.tryParse(classroomId);
    if (serverId == null) {
      return getCachedAttendanceSessions(classroomId);
    }

    try {
      final raw = await _fetchAllItems(
        ApiEndpoints.attendanceSessions,
        queryParams: {'classroom': serverId},
      );
      final sessions = parseModelList(raw, AttendanceSession.fromJson);

      final pendingLocal = getCachedAttendanceSessions(classroomId)
          .where((s) => s.isPendingSync)
          .toList();

      final byDate = <String, AttendanceSession>{
        for (final s in sessions) s.date: s,
        for (final p in pendingLocal) p.date: p,
      };
      final merged = byDate.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      await _cacheBox.put(
        _attendanceSessionsKey(classroomId),
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedAttendanceSessions(classroomId);
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<AttendanceSession> getCachedAttendanceSessions(String classroomId) {
    final raw = _cacheBox.get(_attendanceSessionsKey(classroomId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      return parseModelList(jsonDecode(raw), AttendanceSession.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<AttendanceSession> recordAttendanceSession({
    required String classroomId,
    required String date,
    String remarks = '',
    required List<StudentAttendanceEntry> records,
  }) async {
    final deps = <String>[];
    final isClassTemp = classroomId.startsWith(IdMappingStore.tempPrefix);
    if (isClassTemp) deps.add(classroomId);

    final serializedRecords = <JsonMap>[];
    for (final entry in records) {
      final isStuTemp = entry.studentId.startsWith(IdMappingStore.tempPrefix);
      if (isStuTemp && !deps.contains(entry.studentId)) {
        deps.add(entry.studentId);
      }

      serializedRecords.add({
        'student': isStuTemp ? entry.studentId : int.parse(entry.studentId),
        'status': entry.status.apiValue,
        if (entry.notes.trim().isNotEmpty) 'notes': entry.notes.trim(),
      });
    }

    final payload = <String, dynamic>{
      'date': date,
      if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
      'records': serializedRecords,
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }

      final response = await _apiClient.post(
        ApiEndpoints.classroomRecordAttendance(int.parse(classroomId)),
        body: payload,
      );

      final saved = response is Map
          ? AttendanceSession.fromJson(Map<String, dynamic>.from(response))
          : AttendanceSession(
              id: date,
              classroomId: classroomId,
              date: date,
              remarks: remarks,
              records: records,
            );

      await _upsertCachedSession(classroomId, saved);
      return saved;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'record_attendance',
        method: 'POST',
        endpoint: ApiEndpoints.classroomRecordAttendance(classroomId),
        payload: payload,
        dependsOnTempIds: deps,
      );

      final draft = AttendanceSession(
        id: IdMappingStore.generateTempId('att'),
        classroomId: classroomId,
        date: date,
        remarks: remarks,
        records: records,
        isPendingSync: true,
      );
      await _upsertCachedSession(classroomId, draft);
      return draft;
    }
  }

  Future<void> _upsertCachedSession(
    String classroomId,
    AttendanceSession session,
  ) async {
    final list = List<AttendanceSession>.of(
      getCachedAttendanceSessions(classroomId),
    );
    final idx = list.indexWhere((s) => s.date == session.date);
    if (idx >= 0) {
      list[idx] = session;
    } else {
      list.insert(0, session);
    }
    await _cacheBox.put(
      _attendanceSessionsKey(classroomId),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  // ==========================================
  // GRADEBOOK (`submit-grades/` tied to `LessonGrading`)
  // ==========================================

  Future<List<StudentGrade>> fetchGrades(
    String classroomId, {
    String? lessonPlanId,
    Set<String> enrolledStudentIds = const {},
  }) async {
    final serverId = int.tryParse(classroomId);
    if (serverId == null) {
      return getCachedGrades(classroomId);
    }

    try {
      final lpServerId =
          lessonPlanId != null ? int.tryParse(lessonPlanId) : null;
      final raw = await _fetchAllItems(
        ApiEndpoints.studentGrades,
        queryParams: {
          'grading_task__lesson_grade_level__lp': ?lpServerId,
        },
      );
      var grades = parseModelList(raw, StudentGrade.fromJson);
      if (enrolledStudentIds.isNotEmpty) {
        grades = grades
            .where((g) => enrolledStudentIds.contains(g.studentId))
            .toList();
      }

      final pendingLocal =
          getCachedGrades(classroomId).where((g) => g.isPendingSync).toList();
      final merged = [...pendingLocal, ...grades];

      await _cacheBox.put(
        _gradesKey(classroomId),
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
      return merged;
    } on ApiException catch (e) {
      final cached = getCachedGrades(classroomId);
      if (e.isOffline || cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  List<StudentGrade> getCachedGrades(String classroomId) {
    final raw = _cacheBox.get(_gradesKey(classroomId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      return parseModelList(jsonDecode(raw), StudentGrade.fromJson);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StudentGrade>> submitBatchGrades({
    required String classroomId,
    required List<StudentGrade> entries,
  }) async {
    final deps = <String>[];
    final isClassTemp = classroomId.startsWith(IdMappingStore.tempPrefix);
    if (isClassTemp) deps.add(classroomId);

    final serializedGrades = <JsonMap>[];
    for (final entry in entries) {
      final isStuTemp = entry.studentId.startsWith(IdMappingStore.tempPrefix);
      if (isStuTemp && !deps.contains(entry.studentId)) {
        deps.add(entry.studentId);
      }

      final isTaskTemp =
          entry.gradingTaskId.startsWith(IdMappingStore.tempPrefix);
      if (isTaskTemp && !deps.contains(entry.gradingTaskId)) {
        deps.add(entry.gradingTaskId);
      }

      serializedGrades.add({
        'student': isStuTemp ? entry.studentId : int.parse(entry.studentId),
        'grading_task':
            isTaskTemp ? entry.gradingTaskId : int.parse(entry.gradingTaskId),
        'score': entry.score.toStringAsFixed(2),
        if (entry.feedback.trim().isNotEmpty) 'feedback': entry.feedback.trim(),
      });
    }

    final payload = <String, dynamic>{
      'grades': serializedGrades,
    };

    try {
      if (deps.isNotEmpty) {
        throw ApiException(message: 'Parent record offline', isOffline: true);
      }

      final response = await _apiClient.post(
        ApiEndpoints.classroomSubmitGrades(int.parse(classroomId)),
        body: payload,
      );

      final saved = response is List
          ? parseModelList(response, StudentGrade.fromJson)
          : entries;

      final existing = getCachedGrades(classroomId);
      final upsertedKeys = {
        for (final g in saved) '${g.studentId}_${g.gradingTaskId}',
      };
      final remaining = existing
          .where(
              (g) => !upsertedKeys.contains('${g.studentId}_${g.gradingTaskId}'))
          .toList();
      final updated = [...saved, ...remaining];

      await _cacheBox.put(
        _gradesKey(classroomId),
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
      return saved;
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;

      await _syncQueue.enqueue(
        entityType: 'submit_grades',
        method: 'POST',
        endpoint: ApiEndpoints.classroomSubmitGrades(classroomId),
        payload: payload,
        dependsOnTempIds: deps,
      );

      final optimistic = entries
          .map(
            (g) => StudentGrade(
              id: IdMappingStore.generateTempId('grd'),
              studentId: g.studentId,
              studentName: g.studentName,
              gradingTaskId: g.gradingTaskId,
              gradingTaskName: g.gradingTaskName,
              score: g.score,
              maxScore: g.maxScore,
              feedback: g.feedback,
              isPendingSync: true,
            ),
          )
          .toList();

      final existing = getCachedGrades(classroomId);
      final upsertedKeys = {
        for (final g in optimistic) '${g.studentId}_${g.gradingTaskId}',
      };
      final remaining = existing
          .where(
              (g) => !upsertedKeys.contains('${g.studentId}_${g.gradingTaskId}'))
          .toList();
      final updated = [...optimistic, ...remaining];

      await _cacheBox.put(
        _gradesKey(classroomId),
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
      return optimistic;
    }
  }
}
