import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final List<MethodCall> log = [];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, __) {},
        onCancel: (_) {},
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('KlaviyoSDK.initialize', () {
    test('initializes and sets apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      expect(sdk.isInitialized, isTrue);
      expect(sdk.apiKey, 'KEY_1');
    });

    test('re-initialization updates apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      await sdk.initialize(apiKey: 'KEY_2');
      expect(sdk.isInitialized, isTrue);
      expect(sdk.apiKey, 'KEY_2');
    });

    test('re-initialization forwards new key to native layer', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      await sdk.initialize(apiKey: 'KEY_2');

      final initCalls = log.where((c) => c.method == 'initialize').toList();
      expect(initCalls.length, 2);
      expect(initCalls[0].arguments['apiKey'], 'KEY_1');
      expect(initCalls[1].arguments['apiKey'], 'KEY_2');
    });

    test('failed re-initialization preserves previous apiKey', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      // Make the next native call throw
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'initialize') {
          throw PlatformException(code: 'ERROR', message: 'native failure');
        }
        return null;
      });

      await expectLater(
        sdk.initialize(apiKey: 'KEY_BAD'),
        throwsA(isA<KlaviyoException>()),
      );
      expect(sdk.apiKey, 'KEY_1');
    });
  });

  group('KlaviyoSDK logging toggle', () {
    test('setLoggingEnabled works before initialize', () async {
      // No initialize() call — must not throw KlaviyoNotInitializedException
      await expectLater(KlaviyoSDK().setLoggingEnabled(false), completes);
      await KlaviyoSDK().setLoggingEnabled(true);
    });

    test('setLoggingEnabled forwards flag to native layer', () async {
      final sdk = KlaviyoSDK();
      await sdk.setLoggingEnabled(false);
      await sdk.setLoggingEnabled(true);

      final calls = log.where((c) => c.method == 'setLoggingEnabled').toList();
      expect(calls.length, 2);
      expect(calls[0].arguments['enabled'], isFalse);
      expect(calls[1].arguments['enabled'], isTrue);
    });

    test('isLoggingEnabled returns native value', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'isLoggingEnabled') {
          return false;
        }
        return null;
      });

      expect(await KlaviyoSDK().isLoggingEnabled(), isFalse);
    });

    test('setLoggingEnabled wraps native failures in KlaviyoException',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'native failure');
      });

      await expectLater(
        KlaviyoSDK().setLoggingEnabled(false),
        throwsA(isA<KlaviyoException>()),
      );
      // Dart-side logging must stay untouched when the native call fails,
      // so Dart and native logging state can't disagree.
      expect(Logger('KlaviyoSDK').level, isNot(Level.OFF));
    });
  });
}
