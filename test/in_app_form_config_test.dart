import 'package:flutter/services.dart';
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

    test('isInfinite: true makes a finite config infinite', () {
      final copy = const InAppFormConfig(
        sessionTimeoutDuration: Duration(minutes: 5),
      ).copyWith(isInfinite: true);

      expect(copy.isInfinite, isTrue);
      expect(copy.sessionTimeoutDuration, isNull);
    });

    test('isInfinite: false with no duration falls back to the default', () {
      final copy = const InAppFormConfig.infinite().copyWith(isInfinite: false);

      expect(copy.isInfinite, isFalse);
      expect(copy.sessionTimeoutDuration, isNull);
      expect(copy.toJson(), {'sessionTimeoutDuration': null});
    });

    test('copying a finite config with no args keeps its duration', () {
      final copy = const InAppFormConfig(
        sessionTimeoutDuration: Duration(seconds: 30),
      ).copyWith();

      expect(copy.isInfinite, isFalse);
      expect(copy.sessionTimeoutDuration, const Duration(seconds: 30));
    });

    test('a copied infinite config survives a toJson/fromJson round trip', () {
      final copy = const InAppFormConfig.infinite().copyWith();
      final restored = InAppFormConfig.fromJson(copy.toJson());

      expect(restored.isInfinite, isTrue);
      expect(restored.sessionTimeoutDuration, isNull);
    });
  });

  group('InAppFormConfig channel payload', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    const methodChannel = MethodChannel('klaviyo_sdk');
    final List<MethodCall> log = [];

    setUp(() async {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        log.add(call);
        return null;
      });
      await KlaviyoSDK().initialize(apiKey: 'KEY_1');
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    Map<Object?, Object?>? sentConfiguration() {
      final call = log.lastWhere((c) => c.method == 'registerForInAppForms');
      return call.arguments['configuration'] as Map<Object?, Object?>?;
    }

    test('a copied infinite config is sent as the infinite sentinel', () async {
      await KlaviyoSDK().registerForInAppForms(
        configuration: const InAppFormConfig.infinite().copyWith(),
      );

      expect(sentConfiguration(), {'sessionTimeoutDuration': -1});
    });

    test('a copy with a duration is sent in seconds', () async {
      await KlaviyoSDK().registerForInAppForms(
        configuration: const InAppFormConfig.infinite()
            .copyWith(sessionTimeoutDuration: const Duration(minutes: 2)),
      );

      expect(sentConfiguration(), {'sessionTimeoutDuration': 120});
    });

    test('the sent payload decodes back to the same config', () async {
      await KlaviyoSDK().registerForInAppForms(
        configuration: const InAppFormConfig.infinite().copyWith(),
      );

      final restored = InAppFormConfig.fromJson(
        Map<String, dynamic>.from(sentConfiguration()!),
      );
      expect(restored.isInfinite, isTrue);
    });
  });
}
