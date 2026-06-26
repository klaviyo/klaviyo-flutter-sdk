import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final List<MethodCall> log = [];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, __) {},
        onCancel: (_) {},
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('KlaviyoSDK.initialize', () {
    test('initializes and sets apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      expect(sdk.isInitialized, isTrue);
      expect(sdk.apiKey, 'KEY_1');
    });

    test('re-initialization updates apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      await sdk.initialize(apiKey: 'KEY_2');
      expect(sdk.isInitialized, isTrue);
      expect(sdk.apiKey, 'KEY_2');
    });

    test('re-initialization forwards new key to native layer', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      await sdk.initialize(apiKey: 'KEY_2');

      final initCalls = log.where((c) => c.method == 'initialize').toList();
      expect(initCalls.length, 2);
      expect(initCalls[0].arguments['apiKey'], 'KEY_1');
      expect(initCalls[1].arguments['apiKey'], 'KEY_2');
    });

    test('failed re-initialization preserves previous apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      // Make the next native call throw
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'initialize') {
          throw PlatformException(code: 'ERROR', message: 'native failure');
        }
        return null;
      });

      await expectLater(
        sdk.initialize(apiKey: 'KEY_BAD'),
        throwsA(isA<KlaviyoException>()),
      );
      expect(sdk.apiKey, 'KEY_1');
    });
  });

  group('KlaviyoSDK.getInitialNotification', () {
    test('returns null when no cold-start push is cached', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      final result = await sdk.getInitialNotification();
      expect(result, isNull);
      expect(
        log.where((c) => c.method == 'getInitialNotification').length,
        1,
      );
    });

    test('returns the cached cold-start push payload', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getInitialNotification') {
          return <String, dynamic>{
            'type': 'push_notification_opened',
            'data': <String, dynamic>{
              'klaviyo_id': 'msg-123',
              'deep_link_url': 'klaviyo://open/featured',
              'count': 3,
              'flag': true,
            },
          };
        }
        return null;
      });

      final result = await sdk.getInitialNotification();
      expect(result, isNotNull);
      expect(result!['type'], 'push_notification_opened');
      expect((result['data'] as Map)['klaviyo_id'], 'msg-123');
      expect((result['data'] as Map)['count'], 3);
      expect((result['data'] as Map)['flag'], true);
    });

    test('surfaces native failure as KlaviyoException', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getInitialNotification') {
          throw PlatformException(code: 'ERROR', message: 'native failure');
        }
        return null;
      });

      await expectLater(
        sdk.getInitialNotification(),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });
}
