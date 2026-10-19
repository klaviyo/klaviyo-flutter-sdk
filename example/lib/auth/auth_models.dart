import 'jwt_inspector.dart';
import 'mock_token.dart';

/// What a single scripted provider call does when served.
enum AuthOutcome {
  customToken,
  mockToken,
  throwNetworkError,
  throwOtherError,
}

extension AuthOutcomeLabel on AuthOutcome {
  String get label => switch (this) {
        AuthOutcome.customToken => 'Return custom token',
        AuthOutcome.mockToken => 'Return mock token',
        AuthOutcome.throwNetworkError => 'Throw network error',
        AuthOutcome.throwOtherError => 'Throw other error',
      };
}

/// Whether a generated mock token is structurally valid or deliberately broken.
enum MockTokenKind { valid, malformed }

/// How a valid mock token's expiration is specified.
enum MockExpirationMode { duration, date }

/// Well-formedness of the token most recently returned by the engine.
enum TokenStatus { none, wellFormed, malformed }

/// Computes the [TokenStatus] of a token string (or `null`/empty → none).
TokenStatus tokenStatusOf(String? token) {
  if (token == null || token.trim().isEmpty) return TokenStatus.none;
  return inspectJwt(token)?.exp != null
      ? TokenStatus.wellFormed
      : TokenStatus.malformed;
}

/// Duration presets offered for a valid mock token's lifetime. A negative
/// value mints an already-expired token (shown red in the UI).
const List<Duration> mockDurationPresets = [
  Duration(seconds: 45),
  Duration(seconds: 90),
  Duration(minutes: 5),
  Duration(minutes: -1),
];

int _nextId = 0;

/// A single scripted provider response. Mutable config with a **stable [id]**
/// so served-state and current-call tracking survive list reordering.
class AuthResponse {
  AuthResponse({
    String? id,
    this.outcome = AuthOutcome.mockToken,
    this.customToken = '',
    this.mockKind = MockTokenKind.valid,
    this.mockExpirationMode = MockExpirationMode.duration,
    this.mockDuration = const Duration(seconds: 45),
    this.mockExpiryDate,
    this.delay = Duration.zero,
  }) : id = id ?? 'resp-${_nextId++}';

  final String id;
  AuthOutcome outcome;
  String customToken;
  MockTokenKind mockKind;
  MockExpirationMode mockExpirationMode;
  Duration mockDuration;
  DateTime? mockExpiryDate;
  Duration delay;

  /// A deep copy with a fresh [id] — used by "duplicate".
  AuthResponse duplicate() => AuthResponse(
        outcome: outcome,
        customToken: customToken,
        mockKind: mockKind,
        mockExpirationMode: mockExpirationMode,
        mockDuration: mockDuration,
        mockExpiryDate: mockExpiryDate,
        delay: delay,
      );

  /// The token this response yields when served, or `null` for the throw
  /// outcomes (the engine turns `null` into the appropriate thrown error).
  /// Mock tokens are minted fresh at serve time so `iat` reflects acquisition.
  String? tokenForServing() {
    switch (outcome) {
      case AuthOutcome.customToken:
        return customToken;
      case AuthOutcome.mockToken:
        if (mockKind == MockTokenKind.malformed) return malformedMockToken;
        final now = DateTime.now();
        // Date mode always carries a concrete date (the Configure Response
        // screen defaults one when the mode is selected). The `?? mockDuration`
        // is a defensive fallback tied to the visible duration default rather
        // than a hidden magic value, so the served token can't silently
        // disagree with what the UI shows.
        final expiresAt = mockExpirationMode == MockExpirationMode.duration
            ? now.add(mockDuration)
            : (mockExpiryDate ?? now.add(mockDuration));
        return generateMockToken(issuedAt: now, expiresAt: expiresAt);
      case AuthOutcome.throwNetworkError:
      case AuthOutcome.throwOtherError:
        return null;
    }
  }
}
