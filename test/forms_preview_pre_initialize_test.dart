import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

// KlaviyoSDK is a singleton, so tests that must run before initialize() live
// in their own file to keep a fresh state.

const _token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123-_6';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  bool handleFormsPreviewLinkResult = false;

  setUp(() {
    handleFormsPreviewLinkResult = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'handleFormsPreviewLink') {
        return handleFormsPreviewLinkResult;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('handleFormsPreviewLink before initialize', () {
    test('does not throw and returns false when native is unreachable',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);

      expect(KlaviyoSDK().isInitialized, isFalse);
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
        ),
        isFalse,
      );
    });

    test('forwards to native and returns its result', () async {
      handleFormsPreviewLinkResult = true;
      expect(KlaviyoSDK().isInitialized, isFalse);
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
        ),
        isTrue,
      );
    });
  });
}
