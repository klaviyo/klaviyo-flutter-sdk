/// Base exception class for Klaviyo SDK errors
class KlaviyoException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

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
  const KlaviyoNotInitializedException([
    String message = 'Klaviyo SDK is not initialized',
  ]) : super(message, code: 'NOT_INITIALIZED');
}

/// Exception thrown when API key is invalid or missing
class KlaviyoInvalidApiKeyException extends KlaviyoException {
  const KlaviyoInvalidApiKeyException([
    String message = 'Invalid or missing API key',
  ]) : super(message, code: 'INVALID_API_KEY');
}

/// Exception thrown when network requests fail
class KlaviyoNetworkException extends KlaviyoException {
  final int? statusCode;
  final String? responseBody;

  const KlaviyoNetworkException(
    String message, {
    this.statusCode,
    this.responseBody,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'NETWORK_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'KlaviyoNetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Exception thrown when profile operations fail
class KlaviyoProfileException extends KlaviyoException {
  const KlaviyoProfileException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'PROFILE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when event tracking fails
class KlaviyoEventException extends KlaviyoException {
  const KlaviyoEventException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'EVENT_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when push notification operations fail
class KlaviyoPushException extends KlaviyoException {
  const KlaviyoPushException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'PUSH_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when form operations fail
class KlaviyoFormException extends KlaviyoException {
  const KlaviyoFormException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'FORM_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when configuration is invalid
class KlaviyoConfigurationException extends KlaviyoException {
  const KlaviyoConfigurationException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'CONFIGURATION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when permissions are not granted
class KlaviyoPermissionException extends KlaviyoException {
  const KlaviyoPermissionException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'PERMISSION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
