/// Base exception for Seenn SDK
class SeennException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const SeennException(this.message, {this.code, this.details});

  @override
  String toString() => 'SeennException: $message${code != null ? ' ($code)' : ''}';
}

/// Thrown when SDK is not initialized
class SeennNotInitializedException extends SeennException {
  const SeennNotInitializedException()
      : super('Seenn SDK not initialized. Call Seenn.init() first.');
}

/// Thrown when SDK is already initialized
class SeennAlreadyInitializedException extends SeennException {
  const SeennAlreadyInitializedException()
      : super('Seenn SDK already initialized. Call Seenn.dispose() first.');
}

/// Connection exception
class ConnectionException extends SeennException {
  const ConnectionException(super.message);
}

/// API exception
class SeennApiException extends SeennException {
  final int statusCode;
  final String? requestId;

  const SeennApiException(
    super.message, {
    required this.statusCode,
    super.code,
    this.requestId,
    super.details,
  });

  bool get isRetryable =>
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400;
}
