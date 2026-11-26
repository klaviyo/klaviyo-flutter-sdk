import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Exercises cold-start push delivery end to end through the `klaviyo_events`
/// EventChannel and the `klaviyo_sdk` MethodChannel. The wrapper is a
/// singleton that attaches its channel listener once, so every case runs in
/// order against the same instance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  MockStreamHandlerEventSink? sink;
  Map<String, dynamic>? nativeInitialPush;
  final calls = <String>[];

  Map<String, dynamic> opened(String id) => {
        'type': 'push_notification_opened',
        'data': {'id': id},
      };

  Map<String, dynamic> buttonTap(String id) => {
        'type': 'push_action_button_tapped',
        'data': {'id': id, 'label': 'Shop', 'action': 'open_app'},
      };

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getInitialPushNotification':
          return nativeInitialPush;
        case 'resetProfile':
          nativeInitialPush = null;
          return null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, events) => sink = events),
    );
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    await pumpEventQueue();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('cold-start stream delivery', () {
    test(
      'the first subscriber gets the buffered open, with its action, once',
      () async {
        expect(sink, isNotNull);
        sink!.success({...opened('first'), 'action': buttonTap('btn1')});
        await pumpEventQueue();

        final sdk = KlaviyoSDK();
        final firstOpens = <KlaviyoPushOpened>[];
        final secondOpens = <KlaviyoPushOpened>[];

        final firstSub = sdk.onPushOpened.listen(firstOpens.add);
        await pumpEventQueue();
        final secondSub = sdk.onPushOpened.listen(secondOpens.add);
        await pumpEventQueue();

        expect(firstOpens.map((e) => e.payload['id']), ['first']);
        expect(firstOpens.single.tap, KlaviyoPushTap.actionButton);
        expect(firstOpens.single.button?.id, 'btn1');
        expect(secondOpens, isEmpty);

        await firstSub.cancel();
        await secondSub.cancel();

        final later = <KlaviyoPushOpened>[];
        final laterSub = sdk.onPushOpened.listen(later.add);
        await pumpEventQueue();
        expect(later, isEmpty);
        await laterSub.cancel();
      },
    );

    test('only the newest open is buffered', () async {
      sink!
        ..success({...opened('older'), 'action': buttonTap('btn2')})
        ..success(opened('newer'));
      await pumpEventQueue();

      final opens = <KlaviyoPushOpened>[];
      final sub = KlaviyoSDK().onPushOpened.listen(opens.add);
      await pumpEventQueue();

      expect(opens.map((e) => e.payload['id']), ['newer']);
      expect(opens.single.tap, KlaviyoPushTap.notification);

      await sub.cancel();
    });

    test('resetProfile drops the buffered open', () async {
      sink!.success({...opened('before-reset'), 'action': buttonTap('btn-r')});
      await pumpEventQueue();

      final sdk = KlaviyoSDK();
      await sdk.resetProfile();

      final opens = <KlaviyoPushOpened>[];
      final sub = sdk.onPushOpened.listen(opens.add);
      await pumpEventQueue();

      expect(opens, isEmpty);
      await sub.cancel();
    });

    test('token events still go to the first subscriber only', () async {
      sink!.success({
        'type': 'push_token_received',
        'data': {'token': 'abc'},
      });
      await pumpEventQueue();

      final sdk = KlaviyoSDK();
      final first = <KlaviyoPushToken>[];
      final second = <KlaviyoPushToken>[];
      final firstSub = sdk.onPushToken.listen(first.add);
      await pumpEventQueue();
      final secondSub = sdk.onPushToken.listen(second.add);
      await pumpEventQueue();

      expect(first.single.token, 'abc');
      expect(second, isEmpty);

      await firstSub.cancel();
      await secondSub.cancel();
    });
  });

  group('onPushToken replay', () {
    test(
      'rotated tokens that arrive before any listener go to the first '
      'onPushToken subscriber once as FCM tokens',
      () async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = previousPlatform,
        );

        const registered = KlaviyoPushToken(
          token: 'registered',
          type: KlaviyoPushTokenType.fcm,
        );
        const rotated = KlaviyoPushToken(
          token: 'rotated',
          type: KlaviyoPushTokenType.fcm,
        );
        const rotatedAgain = KlaviyoPushToken(
          token: 'rotated-again',
          type: KlaviyoPushTokenType.fcm,
        );

        await KlaviyoSDK().onPushToken.listen((_) {}).cancel();
        sink!
          ..success({
            'type': 'push_token_received',
            'data': {'token': 'registered'},
          })
          ..success({
            'type': 'push_token_received',
            'data': {'token': 'rotated'},
          });
        await pumpEventQueue();

        final first = <KlaviyoPushToken>[];
        final second = <KlaviyoPushToken>[];
        final firstSub = KlaviyoSDK().onPushToken.listen(first.add);
        await pumpEventQueue();
        final secondSub = KlaviyoSDK().onPushToken.listen(second.add);
        await pumpEventQueue();

        expect(first, [registered, rotated]);
        expect(second, isEmpty);

        sink!.success({
          'type': 'push_token_received',
          'data': {'token': 'rotated-again'},
        });
        await pumpEventQueue();

        expect(first, [registered, rotated, rotatedAgain]);
        expect(second, [rotatedAgain]);

        await firstSub.cancel();
        await secondSub.cancel();
      },
    );
  });

  group('getInitialPushNotification', () {
    test('returns null when the app was not launched by a push tap', () async {
      nativeInitialPush = null;
      expect(await KlaviyoSDK().getInitialPushNotification(), isNull);
    });

    test(
      'returns the launch tap on every call, after the stream consumed it',
      () async {
        nativeInitialPush = opened('launch');
        sink!.success(opened('launch'));
        await pumpEventQueue();

        final sdk = KlaviyoSDK();
        final opens = <KlaviyoPushOpened>[];
        final sub = sdk.onPushOpened.listen(opens.add);
        await pumpEventQueue();
        await sub.cancel();
        expect(opens.map((e) => e.payload['id']), ['launch']);

        final first = await sdk.getInitialPushNotification();
        final second = await sdk.getInitialPushNotification();

        expect(first?.payload, {'id': 'launch'});
        expect(second?.payload, {'id': 'launch'});
        expect(first?.tap, KlaviyoPushTap.notification);
      },
    );

    test('returns null after resetProfile', () async {
      nativeInitialPush = opened('launch');
      final sdk = KlaviyoSDK();
      expect(await sdk.getInitialPushNotification(), isNotNull);

      await sdk.resetProfile();

      expect(await sdk.getInitialPushNotification(), isNull);
    });

    test('reads from native on each call', () async {
      calls.clear();
      await KlaviyoSDK().getInitialPushNotification();
      await KlaviyoSDK().getInitialPushNotification();
      expect(
        calls.where((m) => m == 'getInitialPushNotification'),
        hasLength(2),
      );
    });
  });
}
