import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

Map<String, dynamic> messageMap(String id) => {
      'id': id,
      'defaultDestination': {'type': 'open_app'},
      'isRead': false,
      'isArchived': false,
      'source': 'captured',
    };

void main() {
  group('InboxPage.fromMap', () {
    test('maps messages and the next cursor', () {
      final page = InboxPage.fromMap({
        'messages': [messageMap('a'), messageMap('b')],
        'nextCursor': 'opaque-token',
      });

      expect(page.messages.map((m) => m.id), ['a', 'b']);
      expect(page.nextCursor, 'opaque-token');
    });

    test('treats an absent cursor as the last page', () {
      final page = InboxPage.fromMap({
        'messages': [messageMap('a')],
      });

      expect(page.nextCursor, isNull);
    });

    test('accepts an empty page', () {
      final page = InboxPage.fromMap({'messages': <dynamic>[]});

      expect(page.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('never parses the cursor token', () {
      // The token's contents are the native SDKs' business; it must survive
      // verbatim even when it is not valid base64/JSON.
      const token = 'not-base64-%%%-at-all';
      final page = InboxPage.fromMap({
        'messages': <dynamic>[],
        'nextCursor': token,
      });

      expect(page.nextCursor, token);
    });

    test('throws when messages is missing', () {
      expect(() => InboxPage.fromMap({}), throwsArgumentError);
    });

    test('round trips through toMap', () {
      final original = InboxPage.fromMap({
        'messages': [messageMap('a'), messageMap('b')],
        'nextCursor': 'token',
      });

      final restored = InboxPage.fromMap(original.toMap());

      expect(restored.messages, original.messages);
      expect(restored.nextCursor, original.nextCursor);
    });
  });

  group('KlaviyoInboxException.fromPlatformError', () {
    test('maps every documented native error code', () {
      final cases = {
        'INBOX_STORAGE_FAILURE': KlaviyoInboxErrorReason.storageFailure,
        'INBOX_INVALID_CURSOR': KlaviyoInboxErrorReason.invalidCursor,
        'INBOX_UNAVAILABLE': KlaviyoInboxErrorReason.unavailable,
      };

      for (final entry in cases.entries) {
        final exception = KlaviyoInboxException.fromPlatformError(
          code: entry.key,
          message: 'native said no',
        );

        expect(exception.reason, entry.value, reason: entry.key);
        expect(exception.code, entry.key);
        expect(exception.message, 'native said no');
      }
    });

    test('maps an unknown code to unknown and keeps it', () {
      final exception = KlaviyoInboxException.fromPlatformError(
        code: 'SOMETHING_ELSE',
        message: 'unexpected',
      );

      expect(exception.reason, KlaviyoInboxErrorReason.unknown);
      expect(exception.code, 'SOMETHING_ELSE');
    });

    test('handles a null code and message', () {
      final exception = KlaviyoInboxException.fromPlatformError(
        code: null,
        message: null,
      );

      expect(exception.reason, KlaviyoInboxErrorReason.unknown);
      expect(exception.message, isNotEmpty);
    });

    test('is a KlaviyoException, so existing handlers keep working', () {
      final exception = KlaviyoInboxException.fromPlatformError(
        code: 'INBOX_STORAGE_FAILURE',
        message: 'failed',
      );

      expect(exception, isA<KlaviyoException>());
    });

    test('toString names the reason', () {
      final exception = KlaviyoInboxException.fromPlatformError(
        code: 'INBOX_INVALID_CURSOR',
        message: 'bad cursor',
      );

      expect(exception.toString(), contains('invalidCursor'));
      expect(exception.toString(), contains('INBOX_INVALID_CURSOR'));
    });
  });
}
