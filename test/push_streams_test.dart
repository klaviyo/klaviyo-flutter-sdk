// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Exercises onPushToken, onPushOpened and onPushData end to end through the
/// `klaviyo_events` EventChannel. The wrapper is a singleton that attaches its
/// channel listener once, so cases run in order against the same instance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MockStreamHandlerEventSink? sink;
  // Always-attached listeners so buffered token and push data events don't
  // carry over between tests.
  late List<StreamSubscription<Object>> drains;

  Map<String, dynamic> opened(String id, {Map<String, dynamic>? action}) => {
        'type': 'push_notification_opened',
        'data': {'id': id},
        if (action != null) 'action': action,
      };

  Map<String, dynamic> buttonTap(String id) => {
        'type': 'push_action_button_tapped',
        'data': {
          'id': id,
          'label': 'Shop',
          'action': 'deep_link',
          'url': 'app://shop',
        },
      };

  setUpAll(() async {
    messenger.setMockMethodCallHandler(methodChannel, (_) async => null);
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, events) => sink = events),
    );
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    await pumpEventQueue();
    drains = [
      KlaviyoSDK().onPushToken.listen((_) {}, onError: (_) {}),
      KlaviyoSDK().onPushData.listen((_) {}),
    ];
  });

  tearDownAll(() async {
    for (final drain in drains) {
      await drain.cancel();
    }
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  group('onPushOpened replay', () {
    test('held open reaches every late subscriber', () async {
      sink!.success(opened('cold', action: buttonTap('btn1')));
      await pumpEventQueue();

      final first = <KlaviyoPushOpened>[];
      final second = <KlaviyoPushOpened>[];
      final subA = KlaviyoSDK().onPushOpened.listen(first.add);
      await pumpEventQueue();
      final subB = KlaviyoSDK().onPushOpened.listen(second.add);
      await pumpEventQueue();

      for (final events in [first, second]) {
        expect(events, hasLength(1));
        expect(events.single.payload['id'], 'cold');
        expect(events.single.tap, KlaviyoPushTap.actionButton);
        expect(events.single.button?.id, 'btn1');
      }

      await subA.cancel();
      await subB.cancel();
    });

    test('a live open replaces the held one', () async {
      final live = <KlaviyoPushOpened>[];
      final sub = KlaviyoSDK().onPushOpened.listen(live.add);
      await pumpEventQueue();
      live.clear();

      sink!.success(opened('warm'));
      await pumpEventQueue();
      expect(live.single.payload['id'], 'warm');
      await sub.cancel();

      final late = <KlaviyoPushOpened>[];
      final lateSub = KlaviyoSDK().onPushOpened.listen(late.add);
      await pumpEventQueue();
      expect(late, isEmpty);
      await lateSub.cancel();
    });

    test('an open replayed by native is held for later subscribers', () async {
      final live = <KlaviyoPushOpened>[];
      final sub = KlaviyoSDK().onPushOpened.listen(live.add);
      sink!.success({...opened('native-cached'), 'replayed': true});
      await pumpEventQueue();
      expect(live.single.payload['id'], 'native-cached');
      await sub.cancel();

      final late = <KlaviyoPushOpened>[];
      final lateSub = KlaviyoSDK().onPushOpened.listen(late.add);
      await pumpEventQueue();
      expect(late.single.payload['id'], 'native-cached');
      expect(late.single.payload.containsKey('replayed'), isFalse);
      await lateSub.cancel();
    });

    test('resetProfile clears the held open', () async {
      await KlaviyoSDK().resetProfile();

      final late = <KlaviyoPushOpened>[];
      final sub = KlaviyoSDK().onPushOpened.listen(late.add);
      await pumpEventQueue();
      expect(late, isEmpty);
      await sub.cancel();
    });
  });

  group('onPushOpened', () {
    late List<KlaviyoPushOpened> events;
    late List<KlaviyoPushAction> actions;
    late List<Map<String, dynamic>> raw;
    final subs = <Object>[];

    setUp(() {
      events = [];
      actions = [];
      raw = [];
      final sdk = KlaviyoSDK();
      subs
        ..clear()
        ..addAll([
          sdk.onPushOpened.listen(events.add),
          sdk.onPushAction.listen(actions.add),
          sdk.onPushNotification.listen(raw.add),
        ]);
    });

    tearDown(() async {
      for (final sub in subs) {
        await (sub as dynamic).cancel();
      }
    });

    test('body tap emits one notification open', () async {
      sink!.success(opened('body'));
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.tap, KlaviyoPushTap.notification);
      expect(events.single.button, isNull);
      expect(events.single.webUrl, isNull);
      expect(actions, isEmpty);
    });

    test('button tap emits one open and keeps onPushAction working', () async {
      final action = buttonTap('b1');
      sink!
        ..success(opened('btn', action: action))
        ..success(action);
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.tap, KlaviyoPushTap.actionButton);
      expect(
        events.single.button,
        const KlaviyoPushButton(
          id: 'b1',
          label: 'Shop',
          action: KlaviyoPushButtonAction.deepLink,
          url: 'app://shop',
        ),
      );
      expect(events.single.webUrl, isNull);
      expect(actions.single, isA<ActionButtonTapped>());
      expect(raw.single['type'], 'push_notification_opened');
      expect(raw.single.containsKey('action'), isFalse);
    });

    test('web URL tap emits one open carrying the URL', () async {
      final action = {
        'type': 'push_open_web_url',
        'data': {'url': 'https://example.com'},
      };
      sink!
        ..success(opened('web', action: action))
        ..success(action);
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.tap, KlaviyoPushTap.webUrl);
      expect(events.single.webUrl, 'https://example.com');
      expect(actions.single, const OpenWebUrl(url: 'https://example.com'));
    });

    test('Android open_url button tap emits one webUrl open', () async {
      final action = {
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'b1',
          'label': 'Open Site',
          'action': 'open_url',
          'url': 'https://example.com/shop',
        },
      };
      sink!
        ..success({
          'type': 'push_notification_opened',
          'data': {
            'Button ID': 'b1',
            'Button Action': 'Open URL',
            'Button Link': 'https://example.com/shop',
          },
          'action': action,
        })
        ..success(action);
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.tap, KlaviyoPushTap.actionButton);
      expect(events.single.button?.action, KlaviyoPushButtonAction.openUrl);
      expect(events.single.button?.url, 'https://example.com/shop');
      expect(events.single.webUrl, 'https://example.com/shop');
      expect(
        actions.single,
        const ActionButtonTapped(
          buttonId: 'b1',
          label: 'Open Site',
          action: 'open_url',
          url: 'https://example.com/shop',
        ),
      );
    });

    test('ignores token and push data events', () async {
      sink!
        ..success({
          'type': 'push_token_received',
          'data': {'token': 't'},
        })
        ..success({
          'type': 'silent_push_received',
          'data': {'a': 'b'},
        });
      await pumpEventQueue();

      expect(events, isEmpty);
    });
  });

  group('onPushToken', () {
    test('emits tokens and delivers errors through onError', () async {
      final tokens = <String>[];
      final errors = <Object>[];
      final sub =
          KlaviyoSDK().onPushToken.listen(tokens.add, onError: errors.add);

      sink!
        ..success({
          'type': 'push_token_received',
          'data': {'token': 'abc123'},
        })
        ..success({
          'type': 'push_token_error',
          'data': {'error': 'no entitlement'},
        })
        ..success({
          'type': 'push_token_received',
          'data': {'token': 'def456'},
        });
      await pumpEventQueue();

      expect(tokens, ['abc123', 'def456']);
      expect(errors, hasLength(1));
      final error = errors.single as KlaviyoException;
      expect(error.code, 'PUSH_TOKEN_ERROR');
      expect(error.message, 'no entitlement');
      await sub.cancel();
    });

    test('drops a token event with no token', () async {
      final tokens = <String>[];
      final sub = KlaviyoSDK().onPushToken.listen(tokens.add);

      sink!.success({
        'type': 'push_token_received',
        'data': <String, dynamic>{},
      });
      await pumpEventQueue();

      expect(tokens, isEmpty);
      await sub.cancel();
    });

    test('ignores opens and push data', () async {
      final tokens = <String>[];
      final sub = KlaviyoSDK().onPushToken.listen(tokens.add);

      sink!
        ..success(opened('x'))
        ..success({
          'type': 'silent_push_received',
          'data': {'a': 'b'},
        });
      await pumpEventQueue();

      expect(tokens, isEmpty);
      await sub.cancel();
    });
  });

  group('onPushData', () {
    test('emits push data with key/value pairs hoisted', () async {
      final data = <KlaviyoPushData>[];
      final sub = KlaviyoSDK().onPushData.listen(data.add);

      sink!.success({
        'type': 'silent_push_received',
        'data': {
          '_k': {'c': 'abc'},
          'key_value_pairs': {'promo': 'fall', 'count': 2},
        },
      });
      await pumpEventQueue();

      expect(data, hasLength(1));
      expect(data.single.keyValuePairs, {'promo': 'fall', 'count': '2'});
      expect(data.single.payload['_k'], {'c': 'abc'});
      await sub.cancel();
    });

    test('push without key/value pairs has null keyValuePairs', () async {
      final data = <KlaviyoPushData>[];
      final sub = KlaviyoSDK().onPushData.listen(data.add);

      sink!.success({
        'type': 'silent_push_received',
        'data': {
          '_k': {'c': 'abc'},
        },
      });
      await pumpEventQueue();

      expect(data.single.keyValuePairs, isNull);
      await sub.cancel();
    });

    test('ignores opens and tokens', () async {
      final data = <KlaviyoPushData>[];
      final sub = KlaviyoSDK().onPushData.listen(data.add);

      sink!
        ..success(
          opened('kv')
            ..['data'] = {
              'key_value_pairs': {'a': 'b'},
            },
        )
        ..success({
          'type': 'push_token_received',
          'data': {'token': 't'},
        });
      await pumpEventQueue();

      expect(data, isEmpty);
      await sub.cancel();
    });
  });

  group('KlaviyoPushOpened.fromMap', () {
    test('hoists key/value pairs from a map or an Android JSON string', () {
      final ios = KlaviyoPushOpened.fromMap({
        'type': 'push_notification_opened',
        'data': {
          'key_value_pairs': {'a': 'b'},
        },
      });
      final android = KlaviyoPushOpened.fromMap({
        'type': 'push_notification_opened',
        'data': {'key_value_pairs': '{"a":"b","n":1}'},
      });
      final none = KlaviyoPushOpened.fromMap({
        'type': 'push_notification_opened',
        'data': {'key_value_pairs': 'not json'},
      });

      expect(ios.keyValuePairs, {'a': 'b'});
      expect(android.keyValuePairs, {'a': 'b', 'n': '1'});
      expect(none.keyValuePairs, isNull);
    });

    test('open_app button has no URL', () {
      final event = KlaviyoPushOpened.fromMap(
        opened(
          'x',
          action: {
            'type': 'push_action_button_tapped',
            'data': {'id': 'b', 'action': 'open_app', 'url': ''},
          },
        ),
      );

      expect(event.button?.action, KlaviyoPushButtonAction.openApp);
      expect(event.button?.label, '');
      expect(event.button?.url, isNull);
    });

    test('unknown button action keeps its raw name', () {
      final event = KlaviyoPushOpened.fromMap(
        opened(
          'x',
          action: {
            'type': 'push_action_button_tapped',
            'data': {'id': 'b', 'action': 'share'},
          },
        ),
      );

      expect(event.tap, KlaviyoPushTap.actionButton);
      expect(event.button?.action.name, 'share');
    });

    test('malformed or unknown action falls back to a notification tap', () {
      final missingId = KlaviyoPushOpened.fromMap(
        opened(
          'x',
          action: {
            'type': 'push_action_button_tapped',
            'data': {'action': 'open_app'},
          },
        ),
      );
      final unknown = KlaviyoPushOpened.fromMap(
        opened(
          'x',
          action: {
            'type': 'something_new',
            'data': <String, dynamic>{},
          },
        ),
      );

      expect(missingId.tap, KlaviyoPushTap.notification);
      expect(unknown.tap, KlaviyoPushTap.notification);
    });

    test('payload is unmodifiable', () {
      final event = KlaviyoPushOpened.fromMap(opened('x'));
      expect(() => event.payload['y'] = 1, throwsUnsupportedError);
    });
  });
}
