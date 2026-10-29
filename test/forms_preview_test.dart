import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

const _token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123-_6';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  final List<MethodCall> log = [];
  bool handleFormsPreviewLinkResult = false;

  void setMockHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      if (call.method == 'handleFormsPreviewLink') {
        return handleFormsPreviewLinkResult;
      }
      return null;
    });
  }

  setUp(() async {
    log.clear();
    handleFormsPreviewLinkResult = false;
    setMockHandler();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  List<MethodCall> previewCalls() =>
      log.where((c) => c.method == 'startFormsPreview').toList();

  group('initialized', () {
    setUp(() async {
      await KlaviyoSDK().initialize(apiKey: 'test-api-key');
      log.clear();
    });

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
      List<MethodCall> linkCalls() =>
          log.where((c) => c.method == 'handleFormsPreviewLink').toList();

      test('forwards custom scheme and https links to the native side',
          () async {
        const customScheme = 'myapp://home?klaviyo-forms-preview=$_token';
        const httpsLink =
            'https://shop.example.com/a?utm=qr&klaviyo-forms-preview=$_token&x=1';

        expect(
          await KlaviyoSDK().handleFormsPreviewLink(Uri.parse(customScheme)),
          isFalse,
        );
        expect(
          await KlaviyoSDK().handleFormsPreviewLink(Uri.parse(httpsLink)),
          isFalse,
        );
        expect(linkCalls().map((c) => c.arguments['url']), [
          customScheme,
          httpsLink,
        ]);
      });

      test('returns true when the native side started the preview', () async {
        handleFormsPreviewLinkResult = true;
        expect(
          await KlaviyoSDK().handleFormsPreviewLink(
            Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
          ),
          isTrue,
        );
        expect(linkCalls(), hasLength(1));
      });

      test('returns false when the native side throws', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (call) async {
          log.add(call);
          if (call.method == 'handleFormsPreviewLink') {
            throw PlatformException(code: 'FORMS_ERROR');
          }
          return null;
        });

        expect(
          await KlaviyoSDK().handleFormsPreviewLink(
            Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
          ),
          isFalse,
        );
      });

      test('returns false when the native side returns null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (call) async {
          log.add(call);
          return null;
        });

        expect(
          await KlaviyoSDK().handleFormsPreviewLink(
            Uri.parse('myapp://home?klaviyo-forms-preview=$_token'),
          ),
          isFalse,
        );
        expect(linkCalls(), hasLength(1));
      });

      test('forwards a link without a token for the native side to reject',
          () async {
        expect(
          await KlaviyoSDK()
              .handleFormsPreviewLink(Uri.parse('myapp://home?x=1')),
          isFalse,
        );
        expect(linkCalls(), hasLength(1));
      });

      test('returns false without calling native for a link with no query',
          () async {
        expect(
          await KlaviyoSDK().handleFormsPreviewLink(Uri.parse('myapp://home')),
          isFalse,
        );
        expect(linkCalls(), isEmpty);
      });

      test('returns false for a link with a badly encoded query value',
          () async {
        expect(
          await KlaviyoSDK().handleFormsPreviewLink(
            Uri.parse('myapp://home?utm=%FF&klaviyo-forms-preview=$_token'),
          ),
          isFalse,
        );
        expect(linkCalls(), isEmpty);
      });
    });
  });

  // KlaviyoSDK is a singleton whose initialized state persists across tests
  // in this file, so the pre-initialize cases run in their own file instead:
  // forms_preview_pre_initialize_test.dart.

  test('isValidFormsPreviewToken checks the format', () {
    expect(isValidFormsPreviewToken(_token), isTrue);
    expect(isValidFormsPreviewToken(_token.substring(1)), isFalse);
    expect(isValidFormsPreviewToken('$_token '), isFalse);
    expect(isValidFormsPreviewToken(null), isFalse);
  });
}
