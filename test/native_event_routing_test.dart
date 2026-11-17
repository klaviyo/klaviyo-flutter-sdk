import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  late MockStreamHandlerEventSink sink;
  final sdk = KlaviyoSDK();
  final wrapper = KlaviyoNativeWrapper();
  final logMessages = <String>[];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, events) => sink = events),
    );
    Logger('KlaviyoSDK').onRecord.listen((r) => logMessages.add(r.message));
    await sdk.initialize(apiKey: 'KEY');
    await pumpEventQueue();
  });

  setUp(logMessages.clear);

  Future<List<T>> collect<T>(Stream<T> stream, void Function() emit) async {
    final received = <T>[];
    final sub = stream.listen(received.add);
    emit();
    await pumpEventQueue();
    await sub.cancel();
    return received;
  }

  test('events sent before anyone listens are delivered to the first listener',
      () async {
    sink.success({
      'type': 'push_token_received',
      'data': {'token': 'early'},
    });
    await pumpEventQueue();

    final received = await collect(sdk.onPushNotification, () {});

    expect(received, [
      {
        'type': 'push_token_received',
        'data': {'token': 'early'},
      },
    ]);
  });

  for (final type in [
    'push_notification_received',
    'push_notification_opened',
    'silent_push_received',
    'push_token_received',
    'push_token_error',
  ]) {
    test('$type goes to onPushNotification only', () async {
      final forms = <Map<String, dynamic>>[];
      final formSub = sdk.onFormEvent.listen(forms.add);
      final actions = <Map<String, dynamic>>[];
      final actionSub = wrapper.onPushActionEvent.listen(actions.add);

      final push = await collect(
        sdk.onPushNotification,
        () => sink.success({'type': type, 'data': <String, dynamic>{}}),
      );
      await formSub.cancel();
      await actionSub.cancel();

      expect(push.map((e) => e['type']), [type]);
      expect(forms, isEmpty);
      expect(actions, isEmpty);
    });
  }

  for (final type in ['form_event', 'form_lifecycle_event']) {
    test('$type goes to onFormEvent', () async {
      final received = await collect(
        sdk.onFormEvent,
        () => sink.success({'type': type, 'data': <String, dynamic>{}}),
      );
      expect(received.map((e) => e['type']), [type]);
    });
  }

  test('form lifecycle events are parsed into typed events', () async {
    final received = await collect(
      sdk.onFormLifecycleEvent,
      () {
        sink.success({
          'type': 'form_lifecycle_event',
          'data': {'event': 'formShown', 'formId': 'f1', 'formName': 'Hi'},
        });
        sink.success({
          'type': 'form_lifecycle_event',
          'data': {'event': 'bogus', 'formId': 'f1', 'formName': 'Hi'},
        });
        sink.success({'type': 'form_event', 'data': <String, dynamic>{}});
      },
    );

    expect(received, [const FormShown(formId: 'f1', formName: 'Hi')]);
    expect(logMessages, contains(startsWith('Dropping malformed form')));
  });

  test('push action events go to onPushAction, not onPushNotification',
      () async {
    final push = <Map<String, dynamic>>[];
    final pushSub = sdk.onPushNotification.listen(push.add);

    final received = await collect(sdk.onPushAction, () {
      sink.success({
        'type': 'push_open_web_url',
        'data': {'url': 'https://example.com/private?email=a@b.com'},
      });
      sink.success({
        'type': 'push_action_button_tapped',
        'data': {'id': 'b1', 'action': 'open_app'},
      });
      sink.success({
        'type': 'push_open_web_url',
        'data': <String, dynamic>{},
      });
    });
    await pushSub.cancel();

    expect(received, hasLength(2));
    expect(received[0], isA<OpenWebUrl>());
    expect(received[1], isA<ActionButtonTapped>());
    expect(push, isEmpty);
    expect(logMessages, contains(startsWith('Dropping malformed push action')));
    expect(
      logMessages.where((m) => m.contains('a@b.com')),
      isEmpty,
      reason: 'push action URLs must not be logged',
    );
  });

  test('auth token requests go to the internal auth stream only', () async {
    final push = <Map<String, dynamic>>[];
    final pushSub = sdk.onPushNotification.listen(push.add);

    final received = await collect(
      wrapper.onAuthTokenRequested,
      () => sink.success({
        'type': 'auth_token_requested',
        'data': {'id': 'req-1'},
      }),
    );
    await pushSub.cancel();

    expect(received.single['data'], {'id': 'req-1'});
    expect(push, isEmpty);
  });

  test('unknown event types are dropped', () async {
    final push = <Map<String, dynamic>>[];
    final pushSub = sdk.onPushNotification.listen(push.add);
    final forms = await collect(
      sdk.onFormEvent,
      () => sink.success({'type': 'something_new', 'data': 1}),
    );
    await pushSub.cancel();

    expect(push, isEmpty);
    expect(forms, isEmpty);
  });

  test('nested platform maps and lists become String-keyed maps', () async {
    final received = await collect(
      sdk.onPushNotification,
      () => sink.success(<Object?, Object?>{
        'type': 'push_notification_opened',
        'data': <Object?, Object?>{
          'body': <Object?, Object?>{'_k': 'x', 1: 'int key'},
          'list': [
            <Object?, Object?>{'a': 1},
            [2, 3],
          ],
        },
      }),
    );

    final data = received.single['data'];
    expect(data, isA<Map<String, dynamic>>());
    expect(data['body'], isA<Map<String, dynamic>>());
    expect(data['body'], {'_k': 'x', '1': 'int key'});
    expect(data['list'][0], isA<Map<String, dynamic>>());
    expect(data['list'], [
      {'a': 1},
      [2, 3],
    ]);
  });

  test('an event without a type is dropped', () async {
    final received = await collect(
      sdk.onPushNotification,
      () => sink.success({'data': <String, dynamic>{}}),
    );
    expect(received, isEmpty);
  });

  test('re-initializing does not duplicate events', () async {
    await sdk.initialize(apiKey: 'KEY_2');
    await pumpEventQueue();

    final received = await collect(
      sdk.onPushNotification,
      () => sink.success({'type': 'push_token_received', 'data': {}}),
    );
    expect(received, hasLength(1));
  });
}
