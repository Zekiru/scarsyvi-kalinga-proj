import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_endpoints.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

typedef JsonHeaders = Map<String, String>;

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  return ApiClient(tokenStorage);
});

class ApiClient {
  ApiClient(
    this._tokenStorage, {
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _client = httpClient ?? http.Client();

  final SecureTokenStorage _tokenStorage;
  final http.Client _client;
  final Duration timeout;
  String? _cachedToken;

  void clearCachedToken() {
    _cachedToken = null;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = path.startsWith('http')
        ? path
        : '${ApiEndpoints.baseUrl}$normalizedPath';

    final uri = Uri.parse(fullUrl);
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    final merged = Map<String, String>.from(uri.queryParameters);
    queryParams.forEach((key, value) {
      if (value != null) {
        merged[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: merged);
  }

  Future<JsonHeaders> _buildHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      String? token = _cachedToken;
      if (token == null || token.isEmpty) {
        try {
          token = await _tokenStorage
              .getToken()
              .timeout(const Duration(seconds: 2));
          _cachedToken = token;
        } catch (_) {}
      }
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool includeAuth = true,
  }) {
    return _send(() async {
      final uri = _buildUri(path, queryParams);
      final headers = await _buildHeaders(includeAuth: includeAuth);
      return _client.get(uri, headers: headers);
    });
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParams,
    bool includeAuth = true,
  }) {
    return _send(() async {
      final uri = _buildUri(path, queryParams);
      final headers = await _buildHeaders(includeAuth: includeAuth);
      return _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool includeAuth = true,
  }) {
    return _send(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: includeAuth);
      return _client.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool includeAuth = true,
  }) {
    return _send(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: includeAuth);
      return _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<dynamic> delete(
    String path, {
    bool includeAuth = true,
  }) {
    return _send(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: includeAuth);
      return _client.delete(uri, headers: headers);
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn().timeout(timeout);
      return _parseResponse(response);
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out. Changes will be saved offline.',
        isOffline: true,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        message: 'Network unreachable: ${e.message}',
        isOffline: true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Unable to reach server: $e',
        isOffline: true,
      );
    }
  }

  dynamic _parseResponse(http.Response response) {
    final status = response.statusCode;
    final hasBody = response.body.trim().isNotEmpty;

    dynamic decoded;
    if (hasBody) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = response.body;
      }
    }

    if (status >= 200 && status < 300) {
      return decoded;
    }

    throw ApiException(
      statusCode: status,
      message: _extractErrorMessage(decoded, status),
      details: decoded,
    );
  }

  String _extractErrorMessage(dynamic body, int status) {
    if (body is Map<String, dynamic>) {
      if (body['detail'] != null) return body['detail'].toString();
      if (body['non_field_errors'] is List &&
          (body['non_field_errors'] as List).isNotEmpty) {
        return body['non_field_errors'].first.toString();
      }
      final firstEntry = body.entries.firstOrNull;
      if (firstEntry != null) {
        final val = firstEntry.value;
        final msg = val is List && val.isNotEmpty ? val.first : val;
        return '${firstEntry.key}: $msg';
      }
    }
    return 'Request failed with status $status';
  }
}
