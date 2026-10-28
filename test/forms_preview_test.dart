import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

const _token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123-_6';

void main() {
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
    await KlaviyoSDK().initialize(apiKey: 'test-api-key');
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  List<MethodCall> previewCalls() =>
      log.where((c) => c.method == 'startFormsPreview').toList();

  test('registerForInAppForms sends no preview token', () async {
    await KlaviyoSDK().registerForInAppForms(
      configuration: const InAppFormConfig(),
    );
    final call = log.singleWhere((c) => c.method == 'registerForInAppForms');
    expect(
      (call.arguments['configuration'] as Map).containsKey('previewToken'),
      isFalse,
    );
  });

  group('startFormsPreview and endFormsPreview', () {
    test('send the token to start and no arguments to end', () async {
      await KlaviyoSDK().startFormsPreview(_token);
      await KlaviyoSDK().endFormsPreview();

      expect(previewCalls().map((c) => c.arguments['token']), [_token]);
      final end = log.singleWhere((c) => c.method == 'endFormsPreview');
      expect(end.arguments, isNull);
    });
  });

  group('handleFormsPreviewLink', () {
    test('starts a preview from custom scheme and https links', () async {
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
        ),
        isTrue,
      );
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse(
            'https://shop.example.com/a?utm=qr&klaviyo-forms-preview=$_token&x=1',
          ),
        ),
        isTrue,
      );
      expect(previewCalls().map((c) => c.arguments['token']), [_token, _token]);
    });

    test('returns false and changes nothing for other links', () async {
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(Uri.parse('myapp://home')),
        isFalse,
      );
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('myapp://home?klaviyo-forms-preview=short'),
        ),
        isFalse,
      );
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('https://example.com/#klaviyo-forms-preview=$_token'),
        ),
        isFalse,
      );
      expect(previewCalls(), isEmpty);
    });

    test('returns false for a link with a badly encoded query value', () async {
      expect(
        await KlaviyoSDK().handleFormsPreviewLink(
          Uri.parse('myapp://home?utm=%FF&klaviyo-forms-preview=$_token'),
        ),
        isFalse,
      );
      expect(previewCalls(), isEmpty);
    });
  });

  test('isValidFormsPreviewToken checks the format', () {
    expect(isValidFormsPreviewToken(_token), isTrue);
    expect(isValidFormsPreviewToken(_token.substring(1)), isFalse);
    expect(isValidFormsPreviewToken('$_token '), isFalse);
    expect(isValidFormsPreviewToken(null), isFalse);
  });
}
