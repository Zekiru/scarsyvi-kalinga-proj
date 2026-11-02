/// Error thrown for any failed API call. `toString()` returns just the message,
/// so `Text(e.toString())` in a screen shows a clean message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
