/// Base exception class for Klaviyo SDK errors
class KlaviyoException implements Exception {
  /// A description of what failed.
  final String message;

  /// A machine-readable error code, such as `PUSH_TOKEN_ERROR`, or `null`.
  final String? code;

  /// The error that caused this exception, if any.
  final dynamic originalError;

  /// The stack trace of [originalError], if any.
  final StackTrace? stackTrace;

  /// Creates an exception with [message] and an optional [code].
  const KlaviyoException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'KlaviyoException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}

/// Exception thrown when the SDK is not initialized
class KlaviyoNotInitializedException extends KlaviyoException {
  /// Creates the exception with an optional [message].
  const KlaviyoNotInitializedException([
    super.message = 'Klaviyo SDK is not initialized',
  ]) : super(code: 'NOT_INITIALIZED');
}

/// Exception thrown when API key is invalid or missing
class KlaviyoInvalidApiKeyException extends KlaviyoException {
  /// Creates the exception with an optional [message].
  const KlaviyoInvalidApiKeyException([
    super.message = 'Invalid or missing API key',
  ]) : super(code: 'INVALID_API_KEY');
}

/// Exception thrown when network requests fail
class KlaviyoNetworkException extends KlaviyoException {
  /// The HTTP status code of the failed response, if any.
  final int? statusCode;

  /// The body of the failed response, if any.
  final String? responseBody;

  /// Creates the exception with [message].
  const KlaviyoNetworkException(
    super.message, {
    this.statusCode,
    this.responseBody,
    super.originalError,
    super.stackTrace,
  }) : super(code: 'NETWORK_ERROR');

  @override
  String toString() {
    return 'KlaviyoNetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Exception thrown when profile operations fail
class KlaviyoProfileException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoProfileException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PROFILE_ERROR');
}

/// Exception thrown when event tracking fails
class KlaviyoEventException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoEventException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'EVENT_ERROR');
}

/// Exception thrown when push notification operations fail
class KlaviyoPushException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoPushException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PUSH_ERROR');
}

/// Exception thrown when form operations fail
class KlaviyoFormException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoFormException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'FORM_ERROR');
}

/// Exception thrown when configuration is invalid
class KlaviyoConfigurationException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoConfigurationException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'CONFIGURATION_ERROR');
}

/// Exception thrown when permissions are not granted
class KlaviyoPermissionException extends KlaviyoException {
  /// Creates the exception with [message].
  const KlaviyoPermissionException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PERMISSION_ERROR');
}
