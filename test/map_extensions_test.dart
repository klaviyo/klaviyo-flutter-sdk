import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('isKlaviyoNotification', () {
    test('detects the tracking key at the top level (Android)', () {
      expect(<String, dynamic>{'_k': '{}'}.isKlaviyoNotification, isTrue);
    });

    test('detects the tracking key inside body (iOS)', () {
      expect(
        <String, dynamic>{
          'body': {'_k': '{}'},
        }.isKlaviyoNotification,
        isTrue,
      );
    });

    test('rejects payloads without the tracking key', () {
      expect(<String, dynamic>{}.isKlaviyoNotification, isFalse);
      expect(<String, dynamic>{'title': 'Hi'}.isKlaviyoNotification, isFalse);
      expect(
        <String, dynamic>{'body': 'not a map'}.isKlaviyoNotification,
        isFalse,
      );
      expect(
        <String, dynamic>{
          'body': {'title': 'Hi'},
        }.isKlaviyoNotification,
        isFalse,
      );
    });
  });
}
