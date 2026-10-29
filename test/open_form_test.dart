import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('klaviyo_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final sdk = KlaviyoSDK();
  final calls = <MethodCall>[];

  setUp(() async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await sdk.initialize(apiKey: 'test');
    calls.clear();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('openForm forwards IDs unchanged without registering forms', () async {
    for (final id in [' AbC123 ', '', '   ']) {
      await sdk.openForm(id);
      expect(calls.last.method, 'openForm');
      expect(calls.last.arguments, {'formId': id});
    }
    expect(calls, hasLength(3));
  });

  test('openForm logs platform errors and completes without throwing',
      () async {
    final records = <LogRecord>[];
    final subscription = Logger('KlaviyoSDK').onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'FORMS_NOT_AVAILABLE');
    });

    await expectLater(sdk.openForm('AbC123'), completes);

    expect(
      records.where((record) => record.level >= Level.WARNING),
      contains(
        isA<LogRecord>().having(
          (record) => record.message,
          'message',
          contains('FORMS_NOT_AVAILABLE'),
        ),
      ),
    );
  });
}
