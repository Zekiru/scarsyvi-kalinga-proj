import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use http://10.0.2.2:8000/api/v1 for Android Emulator
  // Use http://127.0.0.1:8000/api/v1 for Web / Desktop / iOS Simulator
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  // Standard JSON Headers
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // CLASSROOMS
  // ---------------------------------------------------------------------------

  /// GET /api/v1/classrooms/
  /// Fetches list of all classrooms with enrolled students and assigned lesson plans.
  Future<List<dynamic>> getClassrooms() async {
    final response = await http.get(
      Uri.parse('$baseUrl/classrooms/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load classrooms: ${response.statusCode}');
    }
  }

  /// GET /api/v1/classrooms/{id}/
  /// Fetches single classroom detail.
  Future<Map<String, dynamic>> getClassroomDetail(int classroomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classrooms/$classroomId/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load classroom detail');
    }
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE
  // ---------------------------------------------------------------------------

  /// GET /api/v1/classrooms/{id}/attendance/
  /// Fetches historical attendance sessions for a classroom.
  Future<List<dynamic>> getAttendance(int classroomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classrooms/$classroomId/attendance/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch attendance logs');
    }
  }

  /// POST /api/v1/classrooms/{id}/attendance/
  /// Logs or updates batch student attendance (Idempotent upsert).
  Future<bool> submitAttendance(int classroomId, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classrooms/$classroomId/attendance/'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to submit attendance: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // GRADES
  // ---------------------------------------------------------------------------

  /// GET /api/v1/classrooms/{id}/grades/
  /// Fetches recorded student grades for a classroom.
  Future<List<dynamic>> getGrades(int classroomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classrooms/$classroomId/grades/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch grades');
    }
  }

  /// POST /api/v1/classrooms/{id}/grades/
  /// Batch creates or updates student scores for assigned lesson grading tasks.
  Future<bool> submitGrades(int classroomId, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classrooms/$classroomId/grades/'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to submit grades: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // CURRICULUM & LESSON PLANS
  // ---------------------------------------------------------------------------

  /// GET /api/v1/lesson-plans/
  /// Fetches all multigrade lesson plans, including associated materials and task weights.
  Future<List<dynamic>> getLessonPlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/lesson-plans/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load lesson plans');
    }
  }

  /// GET /api/v1/materials/
  /// Fetches learning materials and resources.
  Future<List<dynamic>> getMaterials() async {
    final response = await http.get(
      Uri.parse('$baseUrl/materials/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load materials');
    }
  }
}
