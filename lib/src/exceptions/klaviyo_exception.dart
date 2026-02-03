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
    super.message = 'Klaviyo SDK is not initialized',
  ]) : super(code: 'NOT_INITIALIZED');
}

/// Exception thrown when API key is invalid or missing
class KlaviyoInvalidApiKeyException extends KlaviyoException {
  const KlaviyoInvalidApiKeyException([
    super.message = 'Invalid or missing API key',
  ]) : super(code: 'INVALID_API_KEY');
}

/// Exception thrown when network requests fail
class KlaviyoNetworkException extends KlaviyoException {
  final int? statusCode;
  final String? responseBody;

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
  const KlaviyoProfileException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PROFILE_ERROR');
}

/// Exception thrown when event tracking fails
class KlaviyoEventException extends KlaviyoException {
  const KlaviyoEventException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'EVENT_ERROR');
}

/// Exception thrown when push notification operations fail
class KlaviyoPushException extends KlaviyoException {
  const KlaviyoPushException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PUSH_ERROR');
}

/// Exception thrown when form operations fail
class KlaviyoFormException extends KlaviyoException {
  const KlaviyoFormException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'FORM_ERROR');
}

/// Exception thrown when configuration is invalid
class KlaviyoConfigurationException extends KlaviyoException {
  const KlaviyoConfigurationException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'CONFIGURATION_ERROR');
}

/// Exception thrown when permissions are not granted
class KlaviyoPermissionException extends KlaviyoException {
  const KlaviyoPermissionException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(code: 'PERMISSION_ERROR');
}
