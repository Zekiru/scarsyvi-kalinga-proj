import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Convenience helpers so endpoint code reads like:
///   response.ensureSuccess('Failed to load classrooms');
///   return response.decodeList(ClassroomModel.fromJson);
extension ApiResponse on http.Response {
  /// Throws an [ApiException] unless this is a 2xx response.
  void ensureSuccess(String errorPrefix) {
    if (statusCode >= 200 && statusCode < 300) return;

    var details = utf8.decode(bodyBytes);
    if (details.length > 300) details = '${details.substring(0, 300)}…';

    throw ApiException(
      '$errorPrefix ($statusCode): $details',
      statusCode: statusCode,
    );
  }

  /// Decodes the body as UTF-8 JSON (so names with ñ, é, etc. survive).
  dynamic get json => jsonDecode(utf8.decode(bodyBytes));

  Map<String, dynamic> get jsonMap => json as Map<String, dynamic>;

  List<T> decodeList<T>(T Function(Map<String, dynamic>) fromJson) {
    final data = json as List<dynamic>;
    return data.map((item) => fromJson(item as Map<String, dynamic>)).toList();
  }
}
