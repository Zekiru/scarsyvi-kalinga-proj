import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../storage/hive_boxes.dart';

final idMappingStoreProvider = Provider<IdMappingStore>((ref) {
  return IdMappingStore(HiveBoxes.mappings);
});

class IdMappingStore {
  IdMappingStore(this._box);

  final Box<String> _box;

  static const String tempPrefix = 'temp_';

  /// Generates a unique temporary client ID (e.g. `temp_lp_1732098123456`).
  static String generateTempId(String entityPrefix) {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return '$tempPrefix${entityPrefix}_$micros';
  }

  Future<void> saveMapping(String tempId, int serverPk) async {
    await _box.put(tempId, serverPk.toString());
  }

  int? resolveInt(String tempId) {
    final raw = _box.get(tempId);
    return raw != null ? int.tryParse(raw) : null;
  }

  bool hasMapping(String tempId) => _box.containsKey(tempId);

  /// Replaces any `temp_*` substrings in an endpoint URL with mapped integer PKs.
  String resolveEndpoint(String endpoint) {
    var resolved = endpoint;
    for (final key in _box.keys.cast<String>()) {
      if (resolved.contains(key)) {
        final serverId = _box.get(key);
        if (serverId != null) {
          resolved = resolved.replaceAll(key, serverId);
        }
      }
    }
    return resolved;
  }

  /// Deeply traverses Maps and Lists, converting exact `temp_*` strings into integer PKs.
  dynamic resolvePayload(dynamic value) {
    if (value is String) {
      if (value.startsWith(tempPrefix)) {
        final mapped = resolveInt(value);
        if (mapped != null) return mapped;
      }
      return value;
    }
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), resolvePayload(v)),
      );
    }
    if (value is List) {
      return value.map(resolvePayload).toList();
    }
    return value;
  }
}
