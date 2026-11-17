import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('InAppFormConfig.copyWith', () {
    test('copying an infinite config with no args stays infinite', () {
      final copy = const InAppFormConfig.infinite().copyWith();

      expect(copy.isInfinite, isTrue);
      expect(copy.sessionTimeoutDuration, isNull);
      expect(copy.toJson(), {'sessionTimeoutDuration': -1});
    });

    test('passing a duration makes an infinite config finite', () {
      final copy = const InAppFormConfig.infinite()
          .copyWith(sessionTimeoutDuration: const Duration(minutes: 5));

      expect(copy.isInfinite, isFalse);
      expect(copy.sessionTimeoutDuration, const Duration(minutes: 5));
      expect(copy.toJson(), {'sessionTimeoutDuration': 300});
    });

    test('copying a finite config with no args keeps its duration', () {
      final copy = const InAppFormConfig(
        sessionTimeoutDuration: Duration(seconds: 30),
      ).copyWith();

      expect(copy.isInfinite, isFalse);
      expect(copy.sessionTimeoutDuration, const Duration(seconds: 30));
    });

    test('copying the default config with no args keeps the default', () {
      final copy = const InAppFormConfig().copyWith();

      expect(copy.isInfinite, isFalse);
      expect(copy.sessionTimeoutDuration, isNull);
      expect(copy.toJson(), {'sessionTimeoutDuration': null});
    });

    test('a copied infinite config survives a toJson/fromJson round trip', () {
      final copy = const InAppFormConfig.infinite().copyWith();
      final restored = InAppFormConfig.fromJson(copy.toJson());

      expect(restored.isInfinite, isTrue);
      expect(restored.sessionTimeoutDuration, isNull);
    });
  });
}
