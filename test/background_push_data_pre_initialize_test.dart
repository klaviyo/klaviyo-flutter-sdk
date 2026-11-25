import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:klaviyo_flutter_sdk/src/services/background_push_data.dart';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(KlaviyoPushData data) async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    resetBackgroundPushDataHandler();
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('onBackgroundPushData does not require initialize()', () async {
    expect(KlaviyoSDK().isInitialized, isFalse);
    await KlaviyoSDK.onBackgroundPushData(_backgroundHandler);
    expect(log.map((c) => c.method), ['registerBackgroundPushDataHandler']);
    expect(KlaviyoSDK().isInitialized, isFalse);
  });
}
