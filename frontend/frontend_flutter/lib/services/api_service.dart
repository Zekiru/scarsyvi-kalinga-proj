import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:http/http.dart' as http;

import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';
import '../models/attendance_model.dart';
import '../models/student_grade_model.dart';
import 'token_service.dart';

class ApiService {
  final TokenService _tokenService = TokenService();
  VoidCallback? onUnauthenticated;

  /// Dynamic Base URL Resolution based on Target Platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1'; // Android emulator localhost alias
    } else {
      return 'http://127.0.0.1:8000/api/v1'; // iOS / Desktop
    }
  }

  /// Supports runtime overrides via compile-time flag:
  /// flutter run --dart-define=BASE_URL=http://192.168.1.15:8000/api/v1
  static String get configuredBaseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    return envUrl.isNotEmpty ? envUrl : baseUrl;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthenticated?.call();
      throw Exception('Session expired. Please log in again.');
    }
  }

  // --- Auth ---
  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${configuredBaseUrl}/api-token-auth/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Invalid username or password');
    }
  }

  // --- Classrooms ---
  Future<List<ClassroomModel>> fetchClassrooms() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${configuredBaseUrl}/classrooms/'),
      headers: headers,
    );

    _checkResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ClassroomModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load classrooms');
    }
  }

  Future<ClassroomModel> createClassroom(ClassroomModel classroom) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${configuredBaseUrl}/classrooms/'),
      headers: headers,
      body: jsonEncode(classroom.toWriteJson()),
    );

    _checkResponse(response);

    if (response.statusCode == 201) {
      return ClassroomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create classroom');
    }
  }

  // --- Lesson Plans ---
  Future<List<LessonPlanModel>> fetchLessonPlans({String? search, String? learningArea}) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (learningArea != null && learningArea.isNotEmpty) queryParams['learning_area'] = learningArea;

    final uri = Uri.parse('${configuredBaseUrl}/lesson-plans/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    _checkResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => LessonPlanModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load lesson plans');
    }
  }

  // --- Attendance ---
  Future<void> submitAttendance(int classroomId, AttendanceSessionModel session) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${configuredBaseUrl}/classrooms/$classroomId/attendance/'),
      headers: headers,
      body: jsonEncode(session.toJson()),
    );

    _checkResponse(response);

    if (response.statusCode != 201) {
      throw Exception('Failed to submit attendance');
    }
  }

  // --- Grades ---
  Future<void> submitGrades(int classroomId, StudentGradeBatchPayload batchPayload) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${configuredBaseUrl}/classrooms/$classroomId/grades/'),
      headers: headers,
      body: jsonEncode(batchPayload.toJson()),
    );

    _checkResponse(response);

    if (response.statusCode != 201) {
      throw Exception('Failed to submit student grades');
    }
  }
}
