/// Error thrown for any failed API call. `toString()` returns just the message,
/// so `Text(e.toString())` in a screen shows a clean message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  /// True when the server understood the request and rejected it (400-499,
  /// except "timeout" and "too many requests", which are worth retrying).
  /// Retrying the same request will never succeed, so it must not be queued.
  bool get isClientError {
    final code = statusCode;
    return code != null && code >= 400 && code < 500 && code != 408 && code != 429;
  }

  @override
  String toString() => message;
}
