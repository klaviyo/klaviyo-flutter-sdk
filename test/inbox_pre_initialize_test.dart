import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// The inbox API is only meaningful once the SDK is initialized (native reads
/// are scoped to the initialized company), so it throws before then. This file
/// runs in its own isolate and never initializes, which is the pre-init state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('inbox API before initialize', () {
    test('fetchInboxPage throws before initialize', () async {
      expect(KlaviyoSDK().isInitialized, isFalse);

      await expectLater(
        KlaviyoSDK().fetchInboxPage(),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('fetchInboxUnreadCount throws before initialize', () async {
      await expectLater(
        KlaviyoSDK().fetchInboxUnreadCount(),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('updateInboxMessageState throws before initialize', () async {
      await expectLater(
        KlaviyoSDK().updateInboxMessageState('msg-1', InboxMessageState.read),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('clearInboxMessage throws before initialize', () async {
      await expectLater(
        KlaviyoSDK().clearInboxMessage('msg-1'),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('clearInboxMessages throws before initialize', () async {
      await expectLater(
        KlaviyoSDK().clearInboxMessages(['msg-1']),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });
}
