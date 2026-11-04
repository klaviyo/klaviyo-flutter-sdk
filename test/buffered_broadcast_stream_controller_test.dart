import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/src/utils/buffered_broadcast_stream_controller.dart';

void main() {
  late BufferedBroadcastStreamController<String> controller;

  setUp(() {
    controller = BufferedBroadcastStreamController<String>(
      holdKey: (event) => event.startsWith('held') ? event.split(':')[0] : null,
    );
  });

  tearDown(() => controller.close());

  group('held events', () {
    test('replay to every subscriber', () async {
      controller.add('held:1');

      final first = <String>[];
      final second = <String>[];
      final firstSub = controller.stream.listen(first.add);
      await pumpEventQueue();
      final secondSub = controller.stream.listen(second.add);
      await pumpEventQueue();

      expect(first, ['held:1']);
      expect(second, ['held:1']);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('replay to a subscriber that joins after a cancel', () async {
      controller.add('held:1');

      final firstSub = controller.stream.listen((_) {});
      await pumpEventQueue();
      await firstSub.cancel();

      final later = <String>[];
      final laterSub = controller.stream.listen(later.add);
      await pumpEventQueue();

      expect(later, ['held:1']);
      await laterSub.cancel();
    });

    test('keep only the newest event per key', () async {
      controller
        ..add('held:1')
        ..add('held:2');

      final events = <String>[];
      final sub = controller.stream.listen(events.add);
      await pumpEventQueue();

      expect(events, ['held:2']);
      await sub.cancel();
    });

    test('keep one slot per key', () async {
      controller
        ..add('heldA:1')
        ..add('heldB:1');

      final events = <String>[];
      final sub = controller.stream.listen(events.add);
      await pumpEventQueue();

      expect(events, unorderedEquals(['heldA:1', 'heldB:1']));
      await sub.cancel();
    });

    test('are cleared by a newer event delivered live', () async {
      controller.add('held:1');

      final live = <String>[];
      final liveSub = controller.stream.listen(live.add);
      await pumpEventQueue();
      controller.add('held:2');
      await pumpEventQueue();
      expect(live, ['held:1', 'held:2']);

      final later = <String>[];
      final laterSub = controller.stream.listen(later.add);
      await pumpEventQueue();

      expect(later, isEmpty);
      await liveSub.cancel();
      await laterSub.cancel();
    });

    test('are not replayed to a subscriber twice', () async {
      controller.add('held:1');

      final events = <String>[];
      final sub = controller.stream.listen(events.add);
      await pumpEventQueue();
      final otherSub = controller.stream.listen((_) {});
      await pumpEventQueue();

      expect(events, ['held:1']);
      await sub.cancel();
      await otherSub.cancel();
    });

    test('are dropped by clearHeld', () async {
      controller
        ..add('held:1')
        ..clearHeld();

      final events = <String>[];
      final sub = controller.stream.listen(events.add);
      await pumpEventQueue();

      expect(events, isEmpty);
      await sub.cancel();
    });

    test('arrive before live events added after subscribing', () async {
      controller.add('held:1');

      final events = <String>[];
      final sub = controller.stream.listen(events.add);
      controller.add('live');
      await pumpEventQueue();

      expect(events, ['held:1', 'live']);
      await sub.cancel();
    });
  });

  group('unheld events', () {
    test('flush to the first subscriber only', () async {
      controller
        ..add('a')
        ..add('b');

      final first = <String>[];
      final second = <String>[];
      final firstSub = controller.stream.listen(first.add);
      await pumpEventQueue();
      final secondSub = controller.stream.listen(second.add);
      await pumpEventQueue();

      expect(first, ['a', 'b']);
      expect(second, isEmpty);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('reach every live subscriber', () async {
      final first = <String>[];
      final second = <String>[];
      final firstSub = controller.stream.listen(first.add);
      final secondSub = controller.stream.listen(second.add);

      controller.add('a');
      await pumpEventQueue();

      expect(first, ['a']);
      expect(second, ['a']);

      await firstSub.cancel();
      await secondSub.cancel();
    });
  });

  test('without holdKey, buffers everything for the first subscriber',
      () async {
    final plain = BufferedBroadcastStreamController<String>()
      ..add('held:1')
      ..add('b');

    final first = <String>[];
    final second = <String>[];
    final firstSub = plain.stream.listen(first.add);
    await pumpEventQueue();
    final secondSub = plain.stream.listen(second.add);
    await pumpEventQueue();

    expect(first, ['held:1', 'b']);
    expect(second, isEmpty);

    await firstSub.cancel();
    await secondSub.cancel();
    plain.close();
  });

  test('stream is a broadcast stream', () {
    expect(controller.stream.isBroadcast, isTrue);
  });
}
