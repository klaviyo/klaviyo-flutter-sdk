import 'dart:io';

/// Host-provided function that supplies an auth token (JWT) to the SDK.
///
/// Personalized In-App Forms require the SDK to present a user-identifying JWT
/// to the Klaviyo backend. The Flutter SDK is a thin wrapper: the underlying
/// native iOS and Android SDKs own all token state management (caching,
/// proactive refresh, timeouts, WebView injection, and all token-related
/// logging). The wrapper's sole responsibility is to bridge this provider to
/// the native SDK.
///
/// The provider is invoked by the native SDK when it needs a token. It should
/// return the current end-user's JWT, by whatever mechanism the host uses to
/// obtain one (calling its auth server, exchanging an OAuth refresh token,
/// reading from a session cache). It should read the current user fresh on
/// each invocation rather than capturing identity at registration.
///
/// **Connectivity failures:** if the provider throws because the device is
/// offline, the native SDK can wait for connectivity to return and retry — but
/// only when it can recognize the failure as a network error. A
/// [SocketException] is auto-detected as a connectivity failure. If the host
/// uses a different networking layer, it can opt in explicitly by throwing an
/// error object exposing a boolean `isConnectivityError` getter set to `true`.
/// All other errors are treated as non-connectivity failures, matching the
/// native SDKs' error classification.
typedef AuthTokenProvider = Future<String> Function();

/// Result of classifying a provider failure before it is sent back to native.
class ClassifiedProviderError {
  /// Human-readable failure message. Never contains a token.
  final String message;

  /// Whether the failure is a connectivity error. When `true`, the native
  /// bridge reconstitutes a typed network error (`URLError` on iOS,
  /// `IOException` on Android) that the SDK's connectivity-driven refresh
  /// retry recognizes.
  final bool isConnectivityError;

  const ClassifiedProviderError({
    required this.message,
    required this.isConnectivityError,
  });
}

/// Classifies a thrown [AuthTokenProvider] failure into a message plus a
/// connectivity flag for the native bridge.
///
/// Classification order:
///  - An explicit boolean `isConnectivityError` marker on the error object is
///    authoritative in both directions — `true` forces connectivity, `false`
///    opts out — regardless of the heuristic below (networking-layer-agnostic).
///  - Otherwise, Dart's canonical offline signal is auto-detected: a
///    [SocketException].
///  - Everything else is a non-connectivity failure.
///
/// Token contents are never part of a failure and are never logged.
ClassifiedProviderError classifyAuthTokenProviderError(Object error) {
  final message = error.toString();

  // An explicit boolean marker wins over the auto-detect heuristic.
  final marker = _readConnectivityMarker(error);
  if (marker != null) {
    return ClassifiedProviderError(
      message: message,
      isConnectivityError: marker,
    );
  }

  return ClassifiedProviderError(
    message: message,
    isConnectivityError: error is SocketException,
  );
}

/// Reads a boolean `isConnectivityError` getter off an arbitrary error object,
/// or returns `null` if the object does not expose one. The dynamic access is
/// guarded so non-conforming errors (including plain strings) simply fall
/// through to auto-detection.
bool? _readConnectivityMarker(Object error) {
  try {
    final dynamic marker = (error as dynamic).isConnectivityError;
    if (marker is bool) {
      return marker;
    }
  } catch (_) {
    // No such getter — fall through to auto-detection.
  }
  return null;
}

/// Parses the correlation `id` out of a raw `auth_token_requested` event.
///
/// The expected native payload shape is
/// `{ "type": "auth_token_requested", "data": { "id": "..." } }`. Returns the
/// non-empty `id` string, or `null` if it is missing/empty (the caller logs and
/// drops). The request payload never carries a token, only the correlation ID.
String? parseAuthTokenRequestedEventId(Map<String, dynamic> event) {
  final data = event['data'];
  final id = data is Map ? data['id'] : null;
  return (id is String && id.isNotEmpty) ? id : null;
}
