import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  MockStreamHandlerEventSink? sink;

  setUpAll(() async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, s) => sink = s,
        onCancel: (_) {},
      ),
    );
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    await pumpEventQueue();
  });

  tearDownAll(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  group('KlaviyoSDK.onPushData', () {
    test('emits typed push data for silent_push_received events', () async {
      final typed = <KlaviyoPushData>[];
      final raw = <Map<String, dynamic>>[];
      final typedSub = KlaviyoSDK().onPushData.listen(typed.add);
      final rawSub = KlaviyoSDK().onPushNotification.listen(raw.add);

      sink!.success({
        'type': 'silent_push_received',
        'data': {
          '_k': {'c': 'abc'},
          'key_value_pairs': {'promo': 'fall', 'count': 2},
        },
      });
      await pumpEventQueue();

      expect(typed, hasLength(1));
      expect(typed.single.keyValuePairs, {'promo': 'fall', 'count': '2'});
      expect(typed.single.payload['_k'], {'c': 'abc'});
      expect(raw.single['type'], 'silent_push_received');

      await typedSub.cancel();
      await rawSub.cancel();
    });

    test('ignores other push events', () async {
      final typed = <KlaviyoPushData>[];
      final sub = KlaviyoSDK().onPushData.listen(typed.add);

      sink!.success({
        'type': 'push_token_received',
        'data': {'token': 't'},
      });
      sink!.success({
        'type': 'push_notification_opened',
        'data': {
          'key_value_pairs': {'a': 'b'},
        },
      });
      await pumpEventQueue();

      expect(typed, isEmpty);
      await sub.cancel();
    });

    test('push without key/value pairs has null keyValuePairs', () async {
      final typed = <KlaviyoPushData>[];
      final sub = KlaviyoSDK().onPushData.listen(typed.add);

      sink!.success({
        'type': 'silent_push_received',
        'data': {
          '_k': {'c': 'abc'},
        },
      });
      await pumpEventQueue();

      expect(typed.single.keyValuePairs, isNull);
      await sub.cancel();
    });
  });

  group('KlaviyoPushData', () {
    test('payload is unmodifiable', () {
      final data = KlaviyoPushData({'a': '1'});
      expect(() => data.payload['b'] = '2', throwsUnsupportedError);
    });
  });
}
