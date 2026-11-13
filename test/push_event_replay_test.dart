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
      'the first subscriber gets the buffered open and action once',
      () async {
        expect(sink, isNotNull);
        sink!
          ..success(opened('first'))
          ..success(buttonTap('btn1'));
        await pumpEventQueue();

        final sdk = KlaviyoSDK();
        final firstOpens = <Map<String, dynamic>>[];
        final secondOpens = <Map<String, dynamic>>[];
        final firstActions = <KlaviyoPushAction>[];
        final secondActions = <KlaviyoPushAction>[];

        final subs = [
          sdk.onPushNotification.listen(firstOpens.add),
          sdk.onPushAction.listen(firstActions.add),
        ];
        await pumpEventQueue();
        subs.addAll([
          sdk.onPushNotification.listen(secondOpens.add),
          sdk.onPushAction.listen(secondActions.add),
        ]);
        await pumpEventQueue();

        expect(firstOpens.map((e) => e['data']['id']), ['first']);
        expect((firstActions.single as ActionButtonTapped).buttonId, 'btn1');
        expect(secondOpens, isEmpty);
        expect(secondActions, isEmpty);

        for (final sub in subs) {
          await sub.cancel();
        }

        final later = <Map<String, dynamic>>[];
        final laterSub = sdk.onPushNotification.listen(later.add);
        await pumpEventQueue();
        expect(later, isEmpty);
        await laterSub.cancel();
      },
    );

    test(
      'only the newest open is buffered, and an open clears the action',
      () async {
        sink!
          ..success(opened('older'))
          ..success(buttonTap('btn2'))
          ..success(opened('newer'));
        await pumpEventQueue();

        final sdk = KlaviyoSDK();
        final opens = <Map<String, dynamic>>[];
        final actions = <KlaviyoPushAction>[];
        final subs = [
          sdk.onPushNotification.listen(opens.add),
          sdk.onPushAction.listen(actions.add),
        ];
        await pumpEventQueue();

        expect(opens.map((e) => e['data']['id']), ['newer']);
        expect(actions, isEmpty);

        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    test('resetProfile drops the buffered open and action', () async {
      sink!
        ..success(opened('before-reset'))
        ..success(buttonTap('btn-reset'));
      await pumpEventQueue();

      final sdk = KlaviyoSDK();
      await sdk.resetProfile();

      final opens = <Map<String, dynamic>>[];
      final actions = <KlaviyoPushAction>[];
      final subs = [
        sdk.onPushNotification.listen(opens.add),
        sdk.onPushAction.listen(actions.add),
      ];
      await pumpEventQueue();

      expect(opens, isEmpty);
      expect(actions, isEmpty);
      for (final sub in subs) {
        await sub.cancel();
      }
    });

    test('token events still go to the first subscriber only', () async {
      sink!.success({
        'type': 'push_token_received',
        'data': {'token': 'abc'},
      });
      await pumpEventQueue();

      final sdk = KlaviyoSDK();
      final first = <Map<String, dynamic>>[];
      final second = <Map<String, dynamic>>[];
      final firstSub = sdk.onPushNotification.listen(first.add);
      await pumpEventQueue();
      final secondSub = sdk.onPushNotification.listen(second.add);
      await pumpEventQueue();

      expect(first.map((e) => e['type']), ['push_token_received']);
      expect(second, isEmpty);

      await firstSub.cancel();
      await secondSub.cancel();
    });
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
        final opens = <Map<String, dynamic>>[];
        final sub = sdk.onPushNotification.listen(opens.add);
        await pumpEventQueue();
        await sub.cancel();
        expect(opens.map((e) => e['data']['id']), ['launch']);

        final first = await sdk.getInitialPushNotification();
        final second = await sdk.getInitialPushNotification();

        expect(first, opened('launch'));
        expect(second, opened('launch'));
        expect(first!['data'], isA<Map<String, dynamic>>());
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
