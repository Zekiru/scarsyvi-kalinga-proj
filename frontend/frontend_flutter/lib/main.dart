import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/attendance_model.dart';
import 'models/classroom_model.dart';
import 'models/lesson_flow_model.dart';
import 'models/lesson_grade_level_model.dart';
import 'models/lesson_grade_material_model.dart';
import 'models/lesson_grading_model.dart';
import 'models/lesson_plan_model.dart';
import 'models/material_model.dart';
import 'models/student_grade_model.dart';
import 'models/student_model.dart';

import 'providers/app_providers.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive for Flutter
  await Hive.initFlutter();

  // 2. Register all Hive Adapters
  Hive.registerAdapter(StudentAttendanceRecordAdapter());
  Hive.registerAdapter(AttendanceSessionModelAdapter());
  Hive.registerAdapter(GradeLevelModelAdapter());
  Hive.registerAdapter(LessonPlanSummaryModelAdapter());
  Hive.registerAdapter(ClassroomModelAdapter());
  Hive.registerAdapter(LessonFlowModelAdapter());
  Hive.registerAdapter(LessonGradeLevelModelAdapter());
  Hive.registerAdapter(LessonGradeMaterialModelAdapter());
  Hive.registerAdapter(LessonGradingModelAdapter());
  Hive.registerAdapter(LessonPlanModelAdapter());
  Hive.registerAdapter(MaterialModelAdapter());
  Hive.registerAdapter(StudentGradeItemAdapter());
  Hive.registerAdapter(StudentGradeBatchPayloadAdapter());
  Hive.registerAdapter(StudentGradeReadModelAdapter());
  Hive.registerAdapter(StudentSortByAdapter());
  Hive.registerAdapter(StudentModelAdapter());

  // 3. Open primary Hive boxes
  await Future.wait([
    Hive.openBox<ClassroomModel>('classrooms_box'),
    Hive.openBox<LessonPlanModel>('lesson_plans_box'),
    Hive.openBox<AttendanceSessionModel>('attendance_box'),
  ]);

  runApp(
    const ProviderScope(
      child: ProjectKalingaApp(),
    ),
  );
}

class ProjectKalingaApp extends ConsumerWidget {
  const ProjectKalingaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Project Kalinga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (isAuthenticated) {
          if (isAuthenticated) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}
