/// The exception the Klaviyo SDK throws, and the error it adds to its streams.
///
/// [code] is `null` unless one of these applies:
/// - `PUSH_TOKEN_ERROR`: a push token registration failure, delivered as an
///   error on `KlaviyoSDK.onPushToken`.
class KlaviyoException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
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
