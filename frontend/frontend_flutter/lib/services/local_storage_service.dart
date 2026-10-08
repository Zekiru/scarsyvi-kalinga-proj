import 'package:hive/hive.dart';
import '../models/attendance_model.dart';
import '../models/classroom_model.dart';
import '../models/lesson_plan_model.dart';
import '../models/material_model.dart';
import '../models/student_grade_model.dart';

class LocalStorageService {
  final Box<ClassroomModel> _classroomBox =
      Hive.box<ClassroomModel>('classrooms_box');
  final Box<LessonPlanModel> _lessonPlanBox =
      Hive.box<LessonPlanModel>('lesson_plans_box');
  final Box<AttendanceSessionModel> _attendanceBox =
      Hive.box<AttendanceSessionModel>('attendance_box');

  // ==========================================
  // CLASSROOMS
  // ==========================================
  List<ClassroomModel> getCachedClassrooms() {
    return _classroomBox.values.toList();
  }

  Future<void> cacheClassrooms(List<ClassroomModel> classrooms) async {
    await _classroomBox.clear();
    final Map<int, ClassroomModel> map = {
      for (var classroom in classrooms)
        (classroom.classroomId ?? classroom.hashCode): classroom
    };
    await _classroomBox.putAll(map);
  }

  Future<void> saveClassroom(ClassroomModel classroom) async {
    final key = classroom.classroomId ?? classroom.hashCode;
    await _classroomBox.put(key, classroom);
  }

  // ==========================================
  // LESSON PLANS
  // ==========================================
  List<LessonPlanModel> getCachedLessonPlans() {
    return _lessonPlanBox.values.toList();
  }

  Future<void> cacheLessonPlans(List<LessonPlanModel> plans) async {
    await _lessonPlanBox.clear();
    final Map<int, LessonPlanModel> map = {
      for (var plan in plans) (plan.lpId ?? plan.hashCode): plan
    };
    await _lessonPlanBox.putAll(map);
  }

  Future<void> saveLessonPlan(LessonPlanModel plan) async {
    final key = plan.lpId ?? plan.hashCode;
    await _lessonPlanBox.put(key, plan);
  }

  // ==========================================
  // ATTENDANCE SESSIONS
  // ==========================================
  List<AttendanceSessionModel> getCachedAttendanceSessions() {
    return _attendanceBox.values.toList();
  }

  Future<void> cacheAttendanceSessions(
      List<AttendanceSessionModel> sessions) async {
    await _attendanceBox.clear();
    final Map<int, AttendanceSessionModel> map = {
      for (var session in sessions) (session.id ?? session.hashCode): session
    };
    await _attendanceBox.putAll(map);
  }

  Future<void> saveAttendanceSession(AttendanceSessionModel session) async {
    final key = session.id ?? session.hashCode;
    await _attendanceBox.put(key, session);
  }

  // ==========================================
  // UTILS
  // ==========================================
  Future<void> clearAllCache() async {
    await Future.wait([
      _classroomBox.clear(),
      _lessonPlanBox.clear(),
      _attendanceBox.clear(),
    ]);
  }
}
