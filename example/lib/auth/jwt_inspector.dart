import 'dart:convert';

/// The two registered claims the Klaviyo SDK reads from a JWT for refresh
/// scheduling. All other claims are opaque to the SDK.
class JwtClaims {
  const JwtClaims({this.exp, this.iat});

  /// Expiration time (`exp`), seconds since epoch, if present and numeric.
  final int? exp;

  /// Issued-at time (`iat`), seconds since epoch, if present and numeric.
  final int? iat;
}

/// Reads the `exp` / `iat` numeric claims from a 3-segment JWT's payload.
///
/// This is a **display-only** inspector — it performs **no** signature
/// verification (matching the SDK, which is not a security boundary for the
/// token). Surrounding whitespace is trimmed. Returns `null` if the string is
/// not a readable 3-segment JWT with a JSON payload.
JwtClaims? inspectJwt(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return null;

  final segments = trimmed.split('.');
  if (segments.length != 3) return null;

  try {
    final payloadJson =
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1])));
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) return null;

    return JwtClaims(
      exp: _readNumericClaim(decoded['exp']),
      iat: _readNumericClaim(decoded['iat']),
    );
  } catch (_) {
    // Unreadable payload (bad base64, non-JSON, etc.) — display as null.
    return null;
  }
}

/// NumericDate claims are seconds since epoch; accept int or (whole) double.
int? _readNumericClaim(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return null;
}
