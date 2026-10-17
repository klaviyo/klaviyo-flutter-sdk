import 'dart:convert';

/// A deliberately malformed, non-JWT string for exercising the SDK's
/// token-rejection path (fails to parse → treated as no token).
const String malformedMockToken = 'not-a-valid-jwt-token';

/// Mints a structurally-valid but **unsigned** JWT (`alg: HS256`, `typ: JWT`)
/// carrying `sub`, `iat`, and `exp` claims and a dummy signature segment.
///
/// This is for manual testing only — the token is not signed and the Klaviyo
/// backend would reject it; it exists so the test app can drive the SDK's
/// client-side parsing/refresh-scheduling with realistic `iat`/`exp` values.
String generateMockToken({
  required DateTime issuedAt,
  required DateTime expiresAt,
}) {
  final header = _base64UrlJson({'alg': 'HS256', 'typ': 'JWT'});
  final payload = _base64UrlJson({
    'sub': 'flutter-example-user',
    'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  });
  // Dummy, unverifiable signature segment — structurally present, not valid.
  const signature = 'Zmx1dHRlci1leGFtcGxlLXNpZ25hdHVyZQ';
  return '$header.$payload.$signature';
}

String _base64UrlJson(Map<String, dynamic> map) {
  final json = utf8.encode(jsonEncode(map));
  // Strip base64 padding to match the compact JWT representation.
  return base64Url.encode(json).replaceAll('=', '');
}
