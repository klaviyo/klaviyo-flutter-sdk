import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk/src/services/klaviyo_native_wrapper.dart';
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

  test('push opens do not log payload data or action URLs', () async {
    final received = await collect(sdk.onPushOpened, () {
      sink.success({
        'type': 'push_notification_opened',
        'data': {'email': 'push-payload@example.com'},
        'action': {
          'type': 'push_open_web_url',
          'data': {'url': 'https://example.com/private'},
        },
      });
    });

    expect(received.single.webUrl, 'https://example.com/private');
    expect(
      logMessages,
      contains('Native push notification event: push_notification_opened'),
    );
    expect(
      logMessages,
      isNot(contains(contains('push-payload@example.com'))),
    );
    expect(
      logMessages,
      isNot(contains(contains('https://example.com/private'))),
    );
  });

  test('auth token requests go to the internal auth stream only', () async {
    final opens = <KlaviyoPushOpened>[];
    final opensSub = sdk.onPushOpened.listen(opens.add);

    final received = await collect(
      wrapper.onAuthTokenRequested,
      () => sink.success({
        'type': 'auth_token_requested',
        'data': {'id': 'req-1'},
      }),
    );
    await opensSub.cancel();

    expect(received.single['data'], {'id': 'req-1'});
    expect(opens, isEmpty);
  });

  test('unknown event types are dropped', () async {
    final opens = <KlaviyoPushOpened>[];
    final opensSub = sdk.onPushOpened.listen(opens.add);
    final forms = await collect(
      sdk.onFormLifecycleEvent,
      () => sink.success({'type': 'something_new', 'data': 1}),
    );
    await opensSub.cancel();

    expect(opens, isEmpty);
    expect(forms, isEmpty);
  });

  test('nested platform maps and lists become String-keyed maps', () async {
    final received = await collect(
      sdk.onPushOpened,
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

    final data = received.single.payload;
    expect(data, isA<Map<String, dynamic>>());
    expect(data['body'], isA<Map<String, dynamic>>());
    expect(data['body'], {'_k': 'x', '1': 'int key'});
    expect(data['list'][0], isA<Map<String, dynamic>>());
    expect(data['list'], [
      {'a': 1},
      [2, 3],
    ]);
  });

  test('re-initializing does not duplicate events', () async {
    await sdk.initialize(apiKey: 'KEY_2');
    await pumpEventQueue();

    final received = await collect(
      sdk.onPushToken,
      () => sink.success({
        'type': 'push_token_received',
        'data': {'token': 'rotated'},
      }),
    );
    expect(received, hasLength(1));
  });
}
