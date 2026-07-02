import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/src/utils/buffered_broadcast_stream_controller.dart';

void main() {
  // This controller is the mechanism that makes cold-start push-opened
  // delivery work: a native event can arrive before any Dart listener has
  // subscribed (e.g. a notification tap that cold-launches the app), and it
  // must not be dropped. It should be buffered and flushed to the first
  // subscriber — mirroring the native-side cache-then-flush on both platforms.
  group('BufferedBroadcastStreamController', () {
    late BufferedBroadcastStreamController<String> controller;

    setUp(() {
      controller = BufferedBroadcastStreamController<String>();
    });

    tearDown(() {
      controller.close();
    });

    test('buffers events added before a listener and flushes on subscribe',
        () async {
      // Simulate a cold-start event arriving before Flutter subscribes.
      controller.add('cold_start_open');

      // Subscribing later must still receive the buffered event.
      await expectLater(controller.stream, emits('cold_start_open'));
    });

    test('flushes buffered events in order', () async {
      controller.add('first');
      controller.add('second');
      controller.add('third');

      await expectLater(
        controller.stream,
        emitsInOrder(['first', 'second', 'third']),
      );
    });

    test('delivers events live once a listener is attached', () async {
      final received = <String>[];
      final sub = controller.stream.listen(received.add);
      addTearDown(sub.cancel);

      controller.add('live_open');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['live_open']);
    });

    test('does not re-deliver buffered events to later subscribers', () async {
      controller.add('buffered');

      // First subscriber drains the buffer.
      final first = <String>[];
      final firstSub = controller.stream.listen(first.add);
      addTearDown(firstSub.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(first, ['buffered']);

      // A second subscriber joining afterwards must not replay the buffer.
      final second = <String>[];
      final secondSub = controller.stream.listen(second.add);
      addTearDown(secondSub.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(second, isEmpty);
    });

    test('hasListener reflects subscription state', () async {
      expect(controller.hasListener, isFalse);

      final sub = controller.stream.listen((_) {});
      expect(controller.hasListener, isTrue);

      await sub.cancel();
      expect(controller.hasListener, isFalse);
    });
  });
}
