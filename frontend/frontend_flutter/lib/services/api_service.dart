import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:http/http.dart' as http;

import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';
import '../models/attendance_model.dart';
import '../models/student_grade_model.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

export 'api_exception.dart'; // so screens can import ApiException from here

/// The app's API endpoints. HTTP details live in [ApiClient].
class ApiService {
  ApiService({http.Client? client}) : _api = ApiClient(client: client);

  final ApiClient _api;

  /// Called whenever an authenticated request comes back 401.
  VoidCallback? get onUnauthenticated => _api.onUnauthenticated;
  set onUnauthenticated(VoidCallback? callback) =>
      _api.onUnauthenticated = callback;

  // Kept so existing references like ApiService.configuredBaseUrl still work.
  static Duration get requestTimeout => ApiConfig.requestTimeout;
  static String get localBaseUrl => ApiConfig.localBaseUrl;
  static String get configuredBaseUrl => ApiConfig.baseUrl;

  // --- Auth ---
  Future<String> login(String username, String password) async {
    final response = await _api.request(
      'POST',
      '/api-token-auth/',
      body: {'username': username, 'password': password},
      authenticated: false,
    );

    if (response.statusCode != 200) {
      throw const ApiException('Invalid username or password');
    }
    return response.jsonMap['token'] as String;
  }

  // --- Classrooms ---
  Future<List<ClassroomModel>> fetchClassrooms() async {
    final response = await _api.request('GET', '/classrooms/');
    response.ensureSuccess('Failed to load classrooms');
    return response.decodeList(ClassroomModel.fromJson);
  }

  Future<ClassroomModel> createClassroom(ClassroomModel classroom) async {
    final response =
        await _api.request('POST', '/classrooms/', body: classroom.toWriteJson());
    response.ensureSuccess('Failed to create classroom');
    return ClassroomModel.fromJson(response.jsonMap);
  }

  Future<void> updateClassroom(ClassroomModel classroom) async {
    final response = await _api.request(
      'PUT',
      '/classrooms/${classroom.classroomId}/',
      body: classroom.toWriteJson(),
    );
    response.ensureSuccess('Failed to update classroom');
  }

  Future<void> deleteClassroom(int id) async {
    final response = await _api.request('DELETE', '/classrooms/$id/');
    response.ensureSuccess('Failed to delete classroom');
  }

  // --- Lesson Plans ---
  Future<List<LessonPlanModel>> fetchLessonPlans({
    String? search,
    String? learningArea,
  }) async {
    final response = await _api.request(
      'GET',
      '/lesson-plans/',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (learningArea != null && learningArea.isNotEmpty)
          'learning_area': learningArea,
      },
    );
    response.ensureSuccess('Failed to load lesson plans');
    return response.decodeList(LessonPlanModel.fromJson);
  }

  Future<LessonPlanModel> createLessonPlan(LessonPlanModel lessonPlan) async {
    final response = await _api.request(
      'POST',
      '/lesson-plans/',
      body: lessonPlan.toWriteJson(),
    );
    response.ensureSuccess('Failed to create lesson plan');
    return LessonPlanModel.fromJson(response.jsonMap);
  }

  Future<LessonPlanModel> updateLessonPlan(LessonPlanModel lessonPlan) async {
    final response = await _api.request(
      'PUT',
      '/lesson-plans/${lessonPlan.lpId}/',
      body: lessonPlan.toWriteJson(),
    );
    response.ensureSuccess('Failed to update lesson plan');
    return LessonPlanModel.fromJson(response.jsonMap);
  }

  Future<void> deleteLessonPlan(int id) async {
    final response = await _api.request('DELETE', '/lesson-plans/$id/');
    response.ensureSuccess('Failed to delete lesson plan');
  }

  // --- Attendance ---
  Future<void> submitAttendance(
    int classroomId,
    AttendanceSessionModel session,
  ) async {
    final response = await _api.request(
      'POST',
      '/classrooms/$classroomId/attendance/',
      body: session.toJson(),
    );
    response.ensureSuccess('Failed to submit attendance');
  }

  // --- Grades ---
  Future<void> submitGrades(
    int classroomId,
    StudentGradeBatchPayload batchPayload,
  ) async {
    final response = await _api.request(
      'POST',
      '/classrooms/$classroomId/grades/',
      body: batchPayload.toJson(),
    );
    response.ensureSuccess('Failed to submit student grades');
  }
}
