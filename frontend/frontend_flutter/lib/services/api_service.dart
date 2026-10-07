import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';
import '../models/attendance_model.dart';
import '../models/student_grade_model.dart';


class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Adjust base URL for your setup

  // --- Lesson Plans ---
  Future<List<LessonPlanModel>> fetchLessonPlans({String? search, String? learningArea}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (learningArea != null && learningArea.isNotEmpty) queryParams['learning_area'] = learningArea;

    final uri = Uri.parse('$baseUrl/lesson-plans/').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => LessonPlanModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load lesson plans');
    }
  }

  // --- Classrooms ---
  Future<List<ClassroomModel>> fetchClassrooms() async {
    final response = await http.get(Uri.parse('$baseUrl/classrooms/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ClassroomModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load classrooms');
    }
  }

  Future<ClassroomModel> createClassroom(ClassroomModel classroom) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classrooms/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(classroom.toWriteJson()),
    );
    if (response.statusCode == 201) {
      return ClassroomModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create classroom');
    }
  }

  // --- Attendance ---
  Future<void> submitAttendance(int classroomId, AttendanceSessionModel session) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classrooms/$classroomId/attendance/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(session.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to submit attendance');
    }
  }

  // --- Student Grades ---
  Future<void> submitGrades(int classroomId, StudentGradeBatchPayload batchPayload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classrooms/$classroomId/grades/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(batchPayload.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to submit student grades');
    }
  }
}
