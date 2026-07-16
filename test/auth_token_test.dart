import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Error exposing an explicit connectivity marker, used to verify the marker
/// is authoritative over auto-detection in both directions.
class _MarkedError implements Exception {
  _MarkedError(this.isConnectivityError);

  final bool isConnectivityError;

  @override
  String toString() => 'marked error';
}

/// A [SocketException] subtype that also carries an explicit marker, used to
/// prove an explicit `false` overrides the `is SocketException` auto-detection.
class _MarkedSocketException extends SocketException {
  _MarkedSocketException(this.isConnectivityError) : super('marked socket');

  final bool isConnectivityError;
}

/// An error whose text embeds a secret, to prove the classifier never surfaces
/// host-controlled exception text (which could contain the JWT).
class _SecretLeakingError implements Exception {
  @override
  String toString() => 'failed with token=eyJhbGciOiJIUzI1NiJ9.secret.sig';
}

void main() {
  group('classifyAuthTokenProviderError', () {
    test('reports the error type, non-connectivity by default', () {
      final result = classifyAuthTokenProviderError(Exception('boom'));

      // Type is surfaced for diagnosis; the host-controlled text is not.
      expect(result.message, contains('_Exception'));
      expect(result.message, isNot(contains('boom')));
      expect(result.isConnectivityError, isFalse);
    });

    test('never surfaces host-controlled exception text', () {
      final result = classifyAuthTokenProviderError(_SecretLeakingError());

      expect(result.message, isNot(contains('secret')));
      expect(result.message, isNot(contains('eyJ')));
      expect(result.message, contains('_SecretLeakingError'));
    });

    test('classifies a non-Error rejection as non-connectivity', () {
      final result = classifyAuthTokenProviderError('plain string');

      expect(result.isConnectivityError, isFalse);
    });

    test('auto-detects a SocketException as a connectivity failure', () {
      final result = classifyAuthTokenProviderError(
        const SocketException('network is unreachable'),
      );

      expect(result.isConnectivityError, isTrue);
    });

    test('honors an explicit isConnectivityError marker set to true', () {
      final result = classifyAuthTokenProviderError(_MarkedError(true));

      expect(result.isConnectivityError, isTrue);
    });

    test('explicit marker set to false opts out of auto-detection', () {
      final result = classifyAuthTokenProviderError(_MarkedError(false));

      expect(result.isConnectivityError, isFalse);
    });

    test('explicit false marker overrides SocketException auto-detection', () {
      // Even though this IS a SocketException (which would auto-detect as
      // connectivity), the explicit false marker must win.
      final result = classifyAuthTokenProviderError(
        _MarkedSocketException(false),
      );

      expect(result.isConnectivityError, isFalse);
    });
  });

  group('parseAuthTokenRequestedEventId', () {
    test('returns the id from a valid event', () {
      final id = parseAuthTokenRequestedEventId({
        'type': 'auth_token_requested',
        'data': {'id': 'req-123'},
      });

      expect(id, 'req-123');
    });

    test('returns null when data is missing', () {
      expect(
        parseAuthTokenRequestedEventId({'type': 'auth_token_requested'}),
        isNull,
      );
    });

    test('returns null when id is missing', () {
      expect(
        parseAuthTokenRequestedEventId({
          'type': 'auth_token_requested',
          'data': <String, dynamic>{},
        }),
        isNull,
      );
    });

    test('returns null when id is empty', () {
      expect(
        parseAuthTokenRequestedEventId({
          'type': 'auth_token_requested',
          'data': {'id': ''},
        }),
        isNull,
      );
    });

    test('returns null when id is not a string', () {
      expect(
        parseAuthTokenRequestedEventId({
          'type': 'auth_token_requested',
          'data': {'id': 42},
        }),
        isNull,
      );
    });
  });
}
