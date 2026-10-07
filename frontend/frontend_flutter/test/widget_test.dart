// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend_flutter/main.dart'; // Adjust path based on your package name
import 'package:frontend_flutter/providers/app_providers.dart';
import 'package:frontend_flutter/services/api_service.dart';
import 'package:frontend_flutter/models/classroom_model.dart';

// Simple Mock API Service to avoid calling a real backend server during tests
class MockApiService extends ApiService {
  @override
  Future<List<ClassroomModel>> fetchClassrooms() async {
    return [
      ClassroomModel(
        classroomId: 1,
        name: 'Grade 1 & 2 Multigrade',
        schoolName: 'Central Elementary',
        schoolYear: '2026-2027',
        students: [],
        gradeLevels: [],
      ),
    ];
  }
}

void main() {
  testWidgets('App loads and renders bottom navigation and classroom title', (WidgetTester tester) async {
    // Build our app and trigger a frame, overriding the ApiService with MockApiService
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const MultigradeClassroomApp(),
      ),
    );

    // Re-render frame to complete AsyncNotifier loading
    await tester.pumpAndSettle();

    // Verify Navigation Bar labels are present
    expect(find.text('Classrooms'), findsOneWidget);
    expect(find.text('Lesson Plans'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);

    // Verify mock classroom rendered from provider
    expect(find.text('Grade 1 & 2 Multigrade'), findsOneWidget);
  });
}
