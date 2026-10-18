import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

/// These tests exercise the stream pipeline that [KlaviyoSDK.onPushAction]
/// uses: filter by type, parse via [KlaviyoPushAction.fromMap], and drop
/// malformed events without killing the stream. We replicate the pipeline
/// inline rather than requiring platform channel mocking.
void main() {
  late StreamController<Map<String, dynamic>> sourceController;
  late Stream<KlaviyoPushAction> pipeline;
  late Logger logger;
  late List<String> logMessages;

  setUp(() {
    sourceController = StreamController<Map<String, dynamic>>.broadcast();
    logger = Logger('TestPushAction');
    logMessages = [];
    logger.onRecord.listen((record) => logMessages.add(record.message));

    // Mirror the pipeline from KlaviyoSDK.onPushAction
    pipeline = sourceController.stream
        .where(
      (event) =>
          event['type'] == 'push_open_web_url' ||
          event['type'] == 'push_action_button_tapped',
    )
        .expand((event) {
      try {
        return [KlaviyoPushAction.fromMap(event)];
      } catch (e) {
        logger.warning('Dropping malformed push action event: $e');
        return [];
      }
    });
  });

  tearDown(() {
    sourceController.close();
  });

  group('onPushAction stream pipeline', () {
    test('passes through push_open_web_url events', () async {
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      sourceController.add({
        'type': 'push_open_web_url',
        'data': {'url': 'https://klaviyo.com'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(1));
      expect(actions.first, isA<OpenWebUrl>());
      expect((actions.first as OpenWebUrl).url, 'https://klaviyo.com');

      await sub.cancel();
    });

    test('passes through push_action_button_tapped events', () async {
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      sourceController.add({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn1',
          'label': 'Shop',
          'action': 'open_url',
          'url': 'https://klaviyo.com',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(1));
      expect(actions.first, isA<ActionButtonTapped>());
      expect((actions.first as ActionButtonTapped).buttonId, 'btn1');

      await sub.cancel();
    });

    test('filters out non push-action event types', () async {
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      // Push notification / form events must not surface here.
      sourceController.add({
        'type': 'push_notification_opened',
        'data': {'title': 'Hi'},
      });
      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {'event': 'formShown', 'formId': 'f1', 'formName': 'W'},
      });
      sourceController.add({
        'type': 'push_open_web_url',
        'data': {'url': 'https://klaviyo.com'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(1));
      expect(actions.first, isA<OpenWebUrl>());

      await sub.cancel();
    });

    test('drops malformed events without killing the stream', () async {
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      // Malformed: missing required 'url'
      sourceController.add({
        'type': 'push_open_web_url',
        'data': <String, dynamic>{},
      });

      // Valid event after the malformed one
      sourceController.add({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn2',
          'label': 'Open',
          'action': 'deep_link',
          'url': 'myapp://x',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(1));
      expect(actions.first, isA<ActionButtonTapped>());
      expect(
        logMessages,
        contains(contains('Dropping malformed push action event')),
      );

      await sub.cancel();
    });

    test('passes through action button with no label (defaults empty)',
        () async {
      // Real-world shape when the native payload omits the label extra — must
      // surface, not drop.
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      sourceController.add({
        'type': 'push_action_button_tapped',
        'data': {
          'id': 'btn',
          'action': 'deep_link',
          'url': 'myapp://x',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(1));
      expect((actions.first as ActionButtonTapped).label, '');

      await sub.cancel();
    });

    test('multiple events flow through in order', () async {
      final actions = <KlaviyoPushAction>[];
      final sub = pipeline.listen(actions.add);

      sourceController.add({
        'type': 'push_open_web_url',
        'data': {'url': 'https://a.com'},
      });
      sourceController.add({
        'type': 'push_action_button_tapped',
        'data': {'id': 'b', 'label': 'L', 'action': 'open_app'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(2));
      expect(actions[0], isA<OpenWebUrl>());
      expect(actions[1], isA<ActionButtonTapped>());
      expect((actions[1] as ActionButtonTapped).url, isNull);

      await sub.cancel();
    });
  });
}
