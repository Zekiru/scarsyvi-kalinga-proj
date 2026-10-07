import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend_flutter/main.dart'; // Adjust import to your actual project app name
import 'package:frontend_flutter/providers/app_providers.dart';
import 'package:frontend_flutter/services/token_service.dart';
// import 'package:frontend_flutter/services/api_service.dart';

/// Mock TokenService to prevent secure storage access during unit/widget tests
class MockTokenService extends TokenService {
  String? mockToken;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<void> saveToken(String token) async {
    mockToken = token;
  }

  @override
  Future<void> clearToken() async {
    mockToken = null;
  }
}

void main() {
  testWidgets('App renders LoginScreen when unauthenticated', (WidgetTester tester) async {
    final mockTokenService = MockTokenService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenServiceProvider.overrideWithValue(mockTokenService),
        ],
        child: const ProjectKalingaApp(),
      ),
    );

    // Render loading state, then pump to complete initial auth check
    await tester.pumpAndSettle();

    // Verify LoginScreen renders initial elements
    expect(find.text('Project Kalinga'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
