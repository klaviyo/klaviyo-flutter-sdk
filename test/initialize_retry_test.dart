import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk/src/services/klaviyo_native_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('a failed initialize leaves the SDK uninitialized and can be retried',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'INIT_ERROR');
    });

    await expectLater(
      KlaviyoSDK().initialize(apiKey: 'KEY'),
      throwsA(isA<KlaviyoException>()),
    );
    expect(KlaviyoSDK().isInitialized, isFalse);
    expect(KlaviyoNativeWrapper().isInitialized, isFalse);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (_) async => null);
    await KlaviyoSDK().initialize(apiKey: 'KEY');
    expect(KlaviyoSDK().isInitialized, isTrue);
    expect(KlaviyoNativeWrapper().apiKey, 'KEY');
  });
}
