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
      log.where((c) => c.method == 'setFormsPreviewToken').toList();

  group('InAppFormConfig previewToken', () {
    test('is serialized when set', () {
      expect(
        const InAppFormConfig(previewToken: _token).toJson(),
        {'sessionTimeoutDuration': null, 'previewToken': _token},
      );
      expect(
        const InAppFormConfig.infinite(previewToken: _token)
            .toJson()['previewToken'],
        _token,
      );
    });

    test('is omitted when null or empty', () {
      expect(
        const InAppFormConfig().toJson().containsKey('previewToken'),
        isFalse,
      );
      expect(
        const InAppFormConfig(previewToken: '')
            .toJson()
            .containsKey('previewToken'),
        isFalse,
      );
    });

    test('round-trips through fromJson and copyWith', () {
      final config = InAppFormConfig.fromJson({
        'sessionTimeoutDuration': 30,
        'previewToken': _token,
      });
      expect(config.previewToken, _token);
      expect(config.sessionTimeoutDuration, const Duration(seconds: 30));
      expect(config.copyWith(isInfinite: true).previewToken, _token);
    });

    test('toString redacts the token', () {
      expect(
        const InAppFormConfig(previewToken: _token).toString(),
        isNot(contains(_token)),
      );
    });

    test('registerForInAppForms sends the token over the channel', () async {
      await KlaviyoSDK().registerForInAppForms(
        configuration: const InAppFormConfig(previewToken: _token),
      );
      final call = log.singleWhere((c) => c.method == 'registerForInAppForms');
      expect(
        (call.arguments['configuration'] as Map)['previewToken'],
        _token,
      );
    });
  });

  group('setFormsPreviewToken', () {
    test('sends the token, and null to clear', () async {
      await KlaviyoSDK().setFormsPreviewToken(_token);
      await KlaviyoSDK().setFormsPreviewToken(null);
      await KlaviyoSDK().setFormsPreviewToken('');

      final calls = previewCalls();
      expect(calls.map((c) => c.arguments['token']), [_token, null, null]);
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
  });

  test('isValidFormsPreviewToken checks the format', () {
    expect(isValidFormsPreviewToken(_token), isTrue);
    expect(isValidFormsPreviewToken(_token.substring(1)), isFalse);
    expect(isValidFormsPreviewToken('$_token '), isFalse);
    expect(isValidFormsPreviewToken(null), isFalse);
  });
}
