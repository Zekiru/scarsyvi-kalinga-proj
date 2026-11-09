import 'dart:convert';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:http/http.dart' as http;
 
import 'api_config.dart';
import 'api_exception.dart';
import 'token_service.dart';
 
/// Low-level HTTP client: URL building, auth headers, JSON encoding,
/// timeout and 401 handling. Knows nothing about specific endpoints.
class ApiClient {
  ApiClient({http.Client? client, TokenService? tokenService})
      : _client = client ?? http.Client(),
        _tokenService = tokenService ?? TokenService();
 
  final http.Client _client; // injectable so it can be mocked in tests
  final TokenService _tokenService;
 
  /// Called whenever an authenticated request comes back 401.
  VoidCallback? onUnauthenticated;
 
  /// Called after EVERY request with whether the server answered:
  /// true  = got a response (even a 4xx, the server is up)
  /// false = timeout, no connection, or a 5xx (server down / still waking up)
  void Function(bool reachable)? onReachabilityChanged;
 
  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final token = authenticated ? await _tokenService.getToken() : null;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }
 
  /// Sends a request. [path] is relative to the base URL (e.g. `/classrooms/`).
  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = await _headers(authenticated: authenticated);
    final encodedBody = body == null ? null : jsonEncode(body);
 
    final Future<http.Response> call = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ArgumentError('Unsupported HTTP method: $method'),
    };
 
    final http.Response response;
    try {
      response = await call.timeout(ApiConfig.requestTimeout);
    } catch (_) {
      onReachabilityChanged?.call(false); // timeout / no connection
      rethrow;
    }
    onReachabilityChanged?.call(response.statusCode < 500);
 
    if (authenticated && response.statusCode == 401) {
      onUnauthenticated?.call();
      throw const ApiException(
        'Session expired. Please log in again.',
        statusCode: 401,
      );
    }
    return response;
  }
}
