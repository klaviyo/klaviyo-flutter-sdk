/// Estimates the SDK's proactive-refresh time for a token, mirroring the native
/// `AuthTokenManager.refreshTarget` formula:
///
/// ```
/// target = max(iat + 5s, min(iat + 0.9·(exp − iat), exp − 30s))
/// ```
///
/// `iat` is used as a proxy for acquisition time (exact for normal-lifetime
/// tokens). Returns the target as seconds since epoch, or `null` if either
/// claim is missing.
int? estimateRefreshTargetEpoch({int? iat, int? exp}) {
  if (iat == null || exp == null) return null;

  final ninetyPercent = iat + ((exp - iat) * 0.9).round();
  final upperBound = exp - 30; // no later than exp − 30s
  final lowerBound = iat + 5; // no sooner than 5s after issue

  final target = _max(lowerBound, _min(ninetyPercent, upperBound));
  return target;
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
