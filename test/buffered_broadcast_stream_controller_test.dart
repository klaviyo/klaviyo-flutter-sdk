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

  Future<List<String>> collect() async {
    final events = <String>[];
    final sub = controller.stream.listen(events.add);
    await pumpEventQueue();
    await sub.cancel();
    return events;
  }

  group('buffered events', () {
    test('go to the first subscriber once', () async {
      controller
        ..add('held:1')
        ..add('a');

      final first = <String>[];
      final second = <String>[];
      final firstSub = controller.stream.listen(first.add);
      await pumpEventQueue();
      final secondSub = controller.stream.listen(second.add);
      await pumpEventQueue();

      expect(first, ['held:1', 'a']);
      expect(second, isEmpty);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test(
      'are not delivered again after the first subscriber cancels',
      () async {
        controller.add('held:1');

        expect(await collect(), ['held:1']);
        expect(await collect(), isEmpty);
      },
    );

    test('keep only the newest event per hold key', () async {
      controller
        ..add('held:1')
        ..add('held:2');

      expect(await collect(), ['held:2']);
    });

    test('keep one slot per hold key, in arrival order', () async {
      controller
        ..add('heldA:1')
        ..add('heldB:1')
        ..add('heldA:2');

      expect(await collect(), ['heldB:1', 'heldA:2']);
    });

    test('without a hold key are all kept in order', () async {
      controller
        ..add('a')
        ..add('b');

      expect(await collect(), ['a', 'b']);
    });

    test('with a hold key are dropped by clearHeld', () async {
      controller
        ..add('held:1')
        ..add('a')
        ..clearHeld();

      expect(await collect(), ['a']);
    });
  });

  test('live events reach every current subscriber', () async {
    final first = <String>[];
    final second = <String>[];
    final firstSub = controller.stream.listen(first.add);
    final secondSub = controller.stream.listen(second.add);

    controller.add('held:1');
    await pumpEventQueue();

    expect(first, ['held:1']);
    expect(second, ['held:1']);
    expect(await collect(), isEmpty);

    await firstSub.cancel();
    await secondSub.cancel();
  });

  test('stream is a broadcast stream', () {
    expect(controller.stream.isBroadcast, isTrue);
  });
}
