/// The exception the Klaviyo SDK throws, and the error it adds to its streams.
///
/// [code] is `null` unless one of these applies:
/// - `PUSH_TOKEN_ERROR`: a push token registration failure, delivered as an
///   error on `KlaviyoSDK.onPushToken`.
class KlaviyoException implements Exception {
  /// A description of what failed.
  final String message;

  /// A machine-readable error code, such as `PUSH_TOKEN_ERROR`, or `null`.
  final String? code;

  /// The error that caused this exception, if any.
  final Object? originalError;

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
