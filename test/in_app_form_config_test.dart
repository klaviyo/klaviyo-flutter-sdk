import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  test('JSON normalizes recovery durations before numeric conversion', () {
    final oversized = InAppFormConfig.fromJson({
      'loadTimeout': 1e308,
      'eventReplayWindow': 1e308,
    });
    expect(oversized.loadTimeout, isNull);
    expect(oversized.eventReplayWindow, const Duration(seconds: 30));

    final negative = InAppFormConfig.fromJson({
      'loadTimeout': -1e308,
      'eventReplayWindow': -1e308,
    });
    expect(negative.loadTimeout, isNull);
    expect(negative.eventReplayWindow, Duration.zero);

    final representable = InAppFormConfig.fromJson({
      'loadTimeout': 45,
      'eventReplayWindow': 45,
    });
    expect(representable.loadTimeout, const Duration(seconds: 45));
    expect(representable.eventReplayWindow, const Duration(seconds: 30));
  });

  test('JSON retains fractional recovery durations and excludes callbacks', () {
    final config = InAppFormConfig(
      sessionTimeoutDuration: const Duration(seconds: 42),
      loadTimeout: const Duration(microseconds: 1250001),
      eventReplayWindow: Duration.zero,
      onFailure: () {},
    );
    expect(jsonDecode(jsonEncode(config.toJson())), {
      'sessionTimeoutDuration': 42,
      'loadTimeout': 1.250001,
      'eventReplayWindow': 0.0,
    });
    final restored = InAppFormConfig.fromJson(config.toJson());
    expect(restored.loadTimeout, const Duration(microseconds: 1250001));
    expect(restored.eventReplayWindow, Duration.zero);
    expect(restored.onFailure, isNull);
  });

  test('infinite affects only inactivity and survives copyWith', () {
    const config = InAppFormConfig.infinite(
      loadTimeout: Duration(milliseconds: 1500),
      eventReplayWindow: Duration(seconds: 3),
    );
    final copy = config.copyWith();
    expect(copy.toJson(), {
      'sessionTimeoutDuration': -1,
      'loadTimeout': 1.5,
      'eventReplayWindow': 3.0,
    });
    expect(InAppFormConfig.fromJson(copy.toJson()).toJson(), copy.toJson());
    expect(copy.copyWith(isInfinite: false).isInfinite, isFalse);
  });

  test('copyWith preserves replaces and explicitly clears local callback', () {
    void first() {}
    void second() {}
    final config = InAppFormConfig(
      loadTimeout: const Duration(seconds: 2),
      onFailure: first,
    );
    expect(config.copyWith().onFailure, same(first));
    expect(config.copyWith(onFailure: second).onFailure, same(second));
    final cleared = config.copyWith(onFailure: null);
    expect(cleared.onFailure, isNull);
    expect(cleared.loadTimeout, const Duration(seconds: 2));
  });

  test('old config JSON remains accepted without recovery overrides', () {
    expect(InAppFormConfig.fromJson({'sessionTimeoutDuration': 8}).toJson(), {
      'sessionTimeoutDuration': 8,
      'loadTimeout': null,
      'eventReplayWindow': null,
    });
  });
}
