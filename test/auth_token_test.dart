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

void main() {
  group('classifyAuthTokenProviderError', () {
    test('extracts message from an Exception, non-connectivity by default', () {
      final result = classifyAuthTokenProviderError(Exception('boom'));

      expect(result.message, contains('boom'));
      expect(result.isConnectivityError, isFalse);
    });

    test('stringifies a non-Error rejection', () {
      final result = classifyAuthTokenProviderError('plain string');

      expect(result.message, 'plain string');
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
      // A SocketException would auto-detect as connectivity, but an explicit
      // false marker must win.
      final result = classifyAuthTokenProviderError(_MarkedError(false));

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
