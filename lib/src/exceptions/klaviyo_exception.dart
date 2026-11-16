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

/// Why a Mobile Inbox call failed.
///
/// Mirrors the native SDKs' inbox failures. [code] carries the platform error
/// code that produced this exception, so callers can branch on it, but
/// comparing [reason] is the portable way to handle a specific case.
enum KlaviyoInboxErrorReason {
  /// The on-device store could not complete the call.
  storageFailure,

  /// The cursor was malformed, or did not come from this inbox.
  invalidCursor,

  /// The inbox module is not available in this build.
  unavailable,

  /// The platform's native inbox does not support this operation yet.
  ///
  /// Reported for clearing messages on Android, which has no public clear
  /// API. Distinct from [unavailable], which means the module is missing
  /// entirely.
  unsupported,

  /// The native layer reported some other failure.
  unknown,
}

/// Exception thrown when a Mobile Inbox operation fails.
///
/// Carries a [reason] so a caller can distinguish a recoverable problem (an
/// invalid cursor — restart paging from the first page) from one that is not
/// (the store failed).
class KlaviyoInboxException extends KlaviyoException {
  /// The mapped reason for the failure.
  final KlaviyoInboxErrorReason reason;

  const KlaviyoInboxException(
    super.message, {
    required this.reason,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Maps a platform error code to an inbox exception.
  ///
  /// The native layers report `INBOX_STORAGE_FAILURE`, `INBOX_INVALID_CURSOR`,
  /// `INBOX_UNAVAILABLE` and `INBOX_UNSUPPORTED`; anything else is
  /// [KlaviyoInboxErrorReason.unknown] and keeps its code so the original
  /// failure is not lost.
  factory KlaviyoInboxException.fromPlatformError({
    required String? code,
    required String? message,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    final reason = switch (code) {
      'INBOX_STORAGE_FAILURE' => KlaviyoInboxErrorReason.storageFailure,
      'INBOX_INVALID_CURSOR' => KlaviyoInboxErrorReason.invalidCursor,
      'INBOX_UNAVAILABLE' => KlaviyoInboxErrorReason.unavailable,
      'INBOX_UNSUPPORTED' => KlaviyoInboxErrorReason.unsupported,
      _ => KlaviyoInboxErrorReason.unknown,
    };

    return KlaviyoInboxException(
      message ?? 'Mobile Inbox operation failed',
      reason: reason,
      code: code,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    return 'KlaviyoInboxException: $message (Reason: ${reason.name}'
        '${code != null ? ', Code: $code' : ''})';
  }
}
