import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Exercises push event replay end to end through the `klaviyo_events`
/// EventChannel. The wrapper is a singleton that attaches its channel listener
/// once, so every case runs in order against the same instance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  MockStreamHandlerEventSink? sink;

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
        .setMockMethodCallHandler(methodChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) => sink = events,
      ),
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

  test('held open and action reach every subscriber', () async {
    expect(sink, isNotNull);
    sink!
      ..success(opened('first'))
      ..success(buttonTap('btn1'));
    await pumpEventQueue();

    final sdk = KlaviyoSDK();
    final tokenListener = <Map<String, dynamic>>[];
    final router = <Map<String, dynamic>>[];
    final actionsA = <KlaviyoPushAction>[];
    final actionsB = <KlaviyoPushAction>[];

    final subs = [
      sdk.onPushNotification.listen(tokenListener.add),
      sdk.onPushAction.listen(actionsA.add),
    ];
    await pumpEventQueue();
    subs.addAll([
      sdk.onPushNotification.listen(router.add),
      sdk.onPushAction.listen(actionsB.add),
    ]);
    await pumpEventQueue();

    expect(tokenListener.map((e) => e['data']['id']), ['first']);
    expect(router.map((e) => e['data']['id']), ['first']);
    expect(actionsA.single, isA<ActionButtonTapped>());
    expect((actionsB.single as ActionButtonTapped).buttonId, 'btn1');

    for (final sub in subs) {
      await sub.cancel();
    }
  });

  test('a newer open replaces the held open and clears the held action',
      () async {
    sink!.success(opened('second'));
    await pumpEventQueue();

    final sdk = KlaviyoSDK();
    final opens = <Map<String, dynamic>>[];
    final actions = <KlaviyoPushAction>[];
    final subs = [
      sdk.onPushNotification.listen(opens.add),
      sdk.onPushAction.listen(actions.add),
    ];
    await pumpEventQueue();

    expect(opens.map((e) => e['data']['id']), ['second']);
    expect(actions, isEmpty);

    for (final sub in subs) {
      await sub.cancel();
    }
  });

  test('an open delivered live is not replayed to later subscribers', () async {
    final sdk = KlaviyoSDK();
    final live = <Map<String, dynamic>>[];
    final liveSub = sdk.onPushNotification.listen(live.add);
    await pumpEventQueue();
    live.clear();

    sink!.success(opened('third'));
    await pumpEventQueue();
    expect(live.map((e) => e['data']['id']), ['third']);
    await liveSub.cancel();

    final later = <Map<String, dynamic>>[];
    final laterSub = sdk.onPushNotification.listen(later.add);
    await pumpEventQueue();

    expect(later, isEmpty);
    await laterSub.cancel();
  });

  test('token events still flush to the first subscriber only', () async {
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
}
