import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  HiveBoxes._();

  static const String accountsCache = 'cache_accounts';
  static const String curriculumCache = 'cache_curriculum';
  static const String classroomsCache = 'cache_classrooms';
  static const String forumsCache = 'cache_forums';
  static const String syncQueue = 'sync_queue';
  static const String idMappings = 'id_mappings';

  static bool _initialized = false;

  /// Call once in `main()` before `runApp()`.
  /// Register Phase 2 Hive TypeAdapters before calling `openAll()`.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  static Future<void> openAll() async {
    await Future.wait([
      Hive.openBox<String>(accountsCache),
      Hive.openBox<String>(curriculumCache),
      Hive.openBox<String>(classroomsCache),
      Hive.openBox<String>(forumsCache),
      Hive.openBox<String>(idMappings),
    ]);
  }

  static Box<String> get accounts => Hive.box<String>(accountsCache);
  static Box<String> get curriculum => Hive.box<String>(curriculumCache);
  static Box<String> get classrooms => Hive.box<String>(classroomsCache);
  static Box<String> get forums => Hive.box<String>(forumsCache);
  static Box<String> get mappings => Hive.box<String>(idMappings);

  static Future<void> clearUserData() async {
    await Future.wait([
      accounts.clear(),
      curriculum.clear(),
      classrooms.clear(),
      forums.clear(),
      mappings.clear(),
    ]);
  }
}
