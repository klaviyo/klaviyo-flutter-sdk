import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

/// These tests exercise the stream pipeline that [KlaviyoSDK.onFormLifecycleEvent]
/// uses: filter by type, parse via [FormLifecycleEvent.fromMap], and drop
/// malformed events without killing the stream. We replicate the pipeline
/// inline rather than requiring platform channel mocking.
void main() {
  /// Build the same stream transformation that [KlaviyoSDK.onFormLifecycleEvent]
  /// uses, backed by an in-memory [StreamController] instead of the native wrapper.
  late StreamController<Map<String, dynamic>> sourceController;
  late Stream<FormLifecycleEvent> pipeline;
  late Logger logger;
  late List<String> logMessages;

  setUp(() {
    sourceController = StreamController<Map<String, dynamic>>.broadcast();
    logger = Logger('TestFormLifecycle');
    logMessages = [];
    logger.onRecord.listen((record) => logMessages.add(record.message));

    // Mirror the pipeline from KlaviyoSDK.onFormLifecycleEvent
    pipeline = sourceController.stream
        .where((event) => event['type'] == 'form_lifecycle_event')
        .expand((event) {
      try {
        return [FormLifecycleEvent.fromMap(event)];
      } catch (e) {
        logger.warning('Dropping malformed form lifecycle event: $e');
        return [];
      }
    });
  });

  tearDown(() {
    sourceController.close();
  });

  group('onFormLifecycleEvent stream pipeline', () {
    test('passes through form_lifecycle_event events', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formShown',
          'formId': 'f1',
          'formName': 'Welcome',
        },
      });

      // Allow microtasks to flush
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<FormShown>());
      expect(events.first.formId, 'f1');

      await sub.cancel();
    });

    test('filters out events with non-matching type', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      sourceController.add({
        'type': 'push_notification',
        'data': {'token': 'abc123'},
      });

      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formDismissed',
          'formId': 'f2',
          'formName': 'Promo',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<FormDismissed>());

      await sub.cancel();
    });

    test('drops malformed events without killing the stream', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      // Malformed: missing required 'event' field inside data
      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'formId': 'f1',
          'formName': 'Broken',
        },
      });

      // Valid event after the malformed one
      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formShown',
          'formId': 'f3',
          'formName': 'Recovery',
        },
      });

      await Future<void>.delayed(Duration.zero);

      // Malformed event was dropped, but stream survived
      expect(events, hasLength(1));
      expect(events.first.formId, 'f3');
      expect(
        logMessages,
        contains(contains('Dropping malformed form lifecycle event')),
      );

      await sub.cancel();
    });

    test('multiple events flow through in order', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formShown',
          'formId': 'f1',
          'formName': 'First',
        },
      });

      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formCtaClicked',
          'formId': 'f1',
          'formName': 'First',
          'buttonLabel': 'Buy',
          'deepLinkUrl': 'app://buy',
        },
      });

      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formDismissed',
          'formId': 'f1',
          'formName': 'First',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0], isA<FormShown>());
      expect(events[1], isA<FormCtaClicked>());
      expect(events[2], isA<FormDismissed>());

      // Verify order by checking formName is consistent
      for (final event in events) {
        expect(event.formName, 'First');
      }

      await sub.cancel();
    });

    test('drops events with wrong type field value', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      // Wrong type value — should be silently filtered by .where()
      sourceController.add({
        'type': 'form_event',
        'data': {
          'event': 'formShown',
          'formId': 'f1',
          'formName': 'Filtered',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);

      await sub.cancel();
    });

    test('drops event with data that fails type validation', () async {
      final events = <FormLifecycleEvent>[];
      final sub = pipeline.listen(events.add);

      // Has correct outer type but bad inner type field
      sourceController.add({
        'type': 'form_lifecycle_event',
        'data': {
          'event': 'formExploded',
          'formId': 'f1',
          'formName': 'Bad',
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      expect(
        logMessages,
        contains(contains('Dropping malformed form lifecycle event')),
      );

      await sub.cancel();
    });
  });
}
