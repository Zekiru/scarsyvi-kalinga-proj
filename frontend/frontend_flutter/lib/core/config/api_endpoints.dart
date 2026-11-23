import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Override at build/run time via:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl.endsWith('/')
          ? _envBaseUrl.substring(0, _envBaseUrl.length - 1)
          : _envBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  // ==========================================
  // ACCOUNTS (/api/v1/accounts/)
  // ==========================================
  static const String login = '/accounts/login/';
  static const String register = '/accounts/register/';
  static const String me = '/accounts/me/';
  static const String users = '/accounts/users/';
  static String userDetail(int id) => '/accounts/users/$id/';

  // ==========================================
  // CURRICULUM (/api/v1/curriculum/)
  // ==========================================
  static const String gradeLevels = '/curriculum/grade-levels/';
  static const String lessonPlans = '/curriculum/lesson-plans/';
  static String lessonPlanDetail(int id) => '/curriculum/lesson-plans/$id/';
  static String lessonPlanFork(int id) => '/curriculum/lesson-plans/$id/fork/';
  static String lessonPlanAssignChecker(int id) =>
      '/curriculum/lesson-plans/$id/assign-checker/';

  static const String lessonGradeLevels = '/curriculum/lesson-grade-levels/';
  static String lessonGradeLevelDetail(int id) =>
      '/curriculum/lesson-grade-levels/$id/';

  static const String lessonFlows = '/curriculum/lesson-flows/';
  static String lessonFlowDetail(int id) => '/curriculum/lesson-flows/$id/';

  static const String lessonGradings = '/curriculum/lesson-gradings/';
  static String lessonGradingDetail(int id) =>
      '/curriculum/lesson-gradings/$id/';

  static const String materials = '/curriculum/materials/';
  static String materialDetail(int id) => '/curriculum/materials/$id/';

  // ==========================================
  // CLASSROOMS (/api/v1/classrooms/)
  // ==========================================
  static const String classrooms = '/classrooms/classrooms/';
  static String classroomDetail(int id) => '/classrooms/classrooms/$id/';
  static String classroomStudents(int id, {String? ordering}) {
    final base = '/classrooms/classrooms/$id/students/';
    return ordering != null ? '$base?ordering=$ordering' : base;
  }

  static String classroomEnrollStudents(Object id) =>
      '/classrooms/classrooms/$id/enroll-students/';
  static String classroomRecordAttendance(Object id) =>
      '/classrooms/classrooms/$id/record-attendance/';
  static String classroomSubmitGrades(Object id) =>
      '/classrooms/classrooms/$id/submit-grades/';

  static const String students = '/classrooms/students/';
  static String studentDetail(int id) => '/classrooms/students/$id/';

  static const String attendanceSessions = '/classrooms/attendance-sessions/';
  static const String studentGrades = '/classrooms/student-grades/';
  static String studentGradeDetail(int id) =>
      '/classrooms/student-grades/$id/';

  // ==========================================
  // FORUMS (/api/v1/forums/)
  // ==========================================
  static const String forums = '/forums/forums/';
  static String forumDetail(int id) => '/forums/forums/$id/';
  static const String forumByLessonPlan = '/forums/forums/by-lesson-plan/';
  static String forumToggleLock(int id) => '/forums/forums/$id/toggle-lock/';

  static const String threads = '/forums/threads/';
  static String threadDetail(int id) => '/forums/threads/$id/';
  static String threadModerate(int id) => '/forums/threads/$id/moderate/';

  static const String posts = '/forums/posts/';
  static String postDetail(int id) => '/forums/posts/$id/';
  static String postToggleHide(int id) => '/forums/posts/$id/toggle-hide/';
}
