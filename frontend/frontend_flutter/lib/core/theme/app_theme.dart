import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../storage/hive_boxes.dart';

const String _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    if (!Hive.isBoxOpen(HiveBoxes.appSettings)) {
      return ThemeMode.system;
    }
    final saved = HiveBoxes.settings.get(_kThemeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    if (Hive.isBoxOpen(HiveBoxes.appSettings)) {
      await HiveBoxes.settings.put(_kThemeModeKey, mode.name);
    }
  }
}

/// Controls the active ThemeMode across the app (persisted in Hive).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class AppTheme {
  static const Color seedColor = Color(0xFF1B6B52);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      );
}
