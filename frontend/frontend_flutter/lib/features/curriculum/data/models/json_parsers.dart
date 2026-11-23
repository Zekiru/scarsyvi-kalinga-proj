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
  if (v is Map) {
    return asNullableInt(
      v['account_id'] ??
          v['id'] ??
          v['lp_id'] ??
          v['lgl_id'] ??
          v['gl_id'] ??
          v['grade_level_id'] ??
          v['user_id'] ??
          v['pk'],
    );
  }
  return null;
}

String asIdString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is Map) {
    final inner = v['id'] ??
        v['lgl_id'] ??
        v['lp_id'] ??
        v['lf_id'] ??
        v['lg_id'] ??
        v['gl_id'] ??
        v['pk'];
    return inner == null ? fallback : inner.toString();
  }
  return v.toString();
}

String? asNullableIdString(dynamic v) {
  final s = asIdString(v);
  return s.isEmpty ? null : s;
}

double asDouble(dynamic v, [double fallback = 0.0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
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
  final list = raw is List
      ? raw
      : (raw is Map && raw['results'] is List ? raw['results'] as List : null);
  if (list == null) return <T>[];
  final result = <T>[];
  for (final item in list) {
    if (item is Map) {
      result.add(parser(Map<String, dynamic>.from(item)));
    }
  }
  return result;
}
