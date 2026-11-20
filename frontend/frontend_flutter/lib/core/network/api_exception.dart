class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.details,
    this.isOffline = false,
  });

  final String message;
  final int? statusCode;
  final dynamic details;
  final bool isOffline;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Detects DRF `unique_together` validation errors on retry.
  bool get isUniqueConstraintCollision {
    if (statusCode != 400 || details == null) return false;
    final raw = details.toString().toLowerCase();
    return raw.contains('unique') || raw.contains('already exists');
  }

  @override
  String toString() =>
      'ApiException(status: $statusCode, offline: $isOffline, message: $message)';
}
