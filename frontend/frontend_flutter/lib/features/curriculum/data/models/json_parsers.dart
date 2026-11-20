int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  if (v is Map<String, dynamic>) {
    return asNullableInt(
      v['id'] ?? v['lp_id'] ?? v['gl_id'] ?? v['grade_level_id'] ?? v['user_id'],
    );
  }
  return null;
}

String asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

List<T> parseModelList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) parser,
) {
  if (raw is! List) return const [];
  final result = <T>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      result.add(parser(item));
    }
  }
  return result;
}
