import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();

  Future<bool> sendDisplayQuery(String formId) {
    final response = Completer<ByteData?>();
    final query = MethodCall(
      'formWillDisplay',
      {
        'formId': formId,
        'formName': 'Test form',
        'formType': 'POPUP',
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'klaviyo_sdk',
      codec.encodeMethodCall(query),
      response.complete,
    );
    return response.future.then((data) => codec.decodeEnvelope(data!) as bool);
  }

  test('unanswered native gate fails open at three seconds', () async {
    final events = <FormWillDisplay>[];
    final subscription =
        KlaviyoNativeWrapper().onFormWillDisplay.listen(events.add);
    final replies = <bool>[];
    final elapsed = Stopwatch()..start();
    final response = sendDisplayQuery('unanswered').then(replies.add);
    await pumpEventQueue();
    expect(events, hasLength(1));

    try {
      expect(replies, isEmpty);
      await response.timeout(const Duration(seconds: 4));
      expect(replies, [true]);
      expect(elapsed.elapsedMilliseconds, greaterThanOrEqualTo(2900));

      events.single.reject();
      await pumpEventQueue();
      expect(replies, [true]);
    } finally {
      events.single.accept();
      await response;
      await subscription.cancel();
    }
  });

  test('async rejection before the deadline reaches native once', () async {
    final events = <FormWillDisplay>[];
    final subscription =
        KlaviyoNativeWrapper().onFormWillDisplay.listen(events.add);
    final replies = <bool>[];
    final response = sendDisplayQuery('rejected').then(replies.add);
    await pumpEventQueue();
    expect(events, hasLength(1));

    try {
      expect(replies, isEmpty);
      events.single.reject();
      await response;
      expect(replies, [false]);
      events.single.accept();
      await pumpEventQueue();
      expect(replies, [false]);
    } finally {
      events.single.accept();
      await response;
      await subscription.cancel();
    }
  });
}
