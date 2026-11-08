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

  // Declared before the initialize group: the singleton SDK must still be
  // uninitialized when the pre-init test runs.
  group('KlaviyoSDK logging toggle', () {
    test('setLoggingEnabled works before initialize', () async {
      expect(KlaviyoSDK().isInitialized, isFalse);
      // Must not throw KlaviyoNotInitializedException
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

    test('setLoggingEnabled toggles Dart-side logging', () async {
      final sdk = KlaviyoSDK();
      final records = <LogRecord>[];
      final sub = Logger('KlaviyoSDK').onRecord.listen(records.add);

      await sdk.setLoggingEnabled(false);
      expect(Logger('KlaviyoSDK').level, Level.OFF);
      Logger('KlaviyoSDK').info('while disabled');

      await sdk.setLoggingEnabled(true);
      expect(Logger('KlaviyoSDK').level, isNot(Level.OFF));
      Logger('KlaviyoSDK').info('while enabled');

      await sub.cancel();
      expect(records.map((r) => r.message), ['while enabled']);
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

  group('KlaviyoSDK.createSubscription', () {
    test('forwards the subscription payload to the native layer', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.createSubscription(
        const KlaviyoSubscription(
          listId: 'ABC123',
          channels: KlaviyoSubscriptionChannels(
            email: {EmailConsent.marketing},
            sms: {MessagingConsent.marketing},
          ),
          customSource: 'Checkout screen',
        ),
      );

      final call = log.singleWhere((c) => c.method == 'createSubscription');
      expect(call.arguments['subscription'], {
        'listId': 'ABC123',
        'channels': {
          'email': ['marketing'],
          'sms': ['marketing'],
        },
        'customSource': 'Checkout screen',
      });
    });

    test('omits channels for allAvailableMarketing', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.createSubscription(
        const KlaviyoSubscription.allAvailableMarketing(listId: 'ABC123'),
      );

      final call = log.singleWhere((c) => c.method == 'createSubscription');
      expect(call.arguments['subscription'], {'listId': 'ABC123'});
    });

    test('wraps native failures in KlaviyoException', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'SUBSCRIPTION_ERROR', message: 'nope');
      });

      await expectLater(
        sdk.createSubscription(
          const KlaviyoSubscription.allAvailableMarketing(listId: 'ABC123'),
        ),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });

  group('KlaviyoSDK forms and geofencing errors', () {
    void failNativeWith(String code) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'initialize') return null;
        throw PlatformException(code: code, message: 'module missing');
      });
    }

    Matcher throwsKlaviyoCode(String code) => throwsA(
          isA<KlaviyoException>().having((e) => e.code, 'code', code).having(
                (e) => e.originalError,
                'originalError',
                isA<PlatformException>(),
              ),
        );

    final cases = <String, (String, Future<Object?> Function(KlaviyoSDK))>{
      'registerForInAppForms': (
        'FORMS_NOT_AVAILABLE',
        (sdk) => sdk.registerForInAppForms(),
      ),
      'unregisterFromInAppForms': (
        'FORMS_NOT_AVAILABLE',
        (sdk) => sdk.unregisterFromInAppForms(),
      ),
      'registerGeofencing': (
        'GEOFENCING_NOT_AVAILABLE',
        (sdk) => sdk.registerGeofencing(),
      ),
      'unregisterGeofencing': (
        'GEOFENCING_NOT_AVAILABLE',
        (sdk) => sdk.unregisterGeofencing(),
      ),
      'getCurrentGeofences': (
        'GEOFENCING_NOT_AVAILABLE',
        (sdk) => sdk.getCurrentGeofences(),
      ),
    };

    for (final MapEntry(key: method, value: (code, invoke)) in cases.entries) {
      test('$method throws KlaviyoException with native code $code', () async {
        final sdk = KlaviyoSDK();
        await sdk.initialize(apiKey: 'KEY_1');
        failNativeWith(code);

        await expectLater(invoke(sdk), throwsKlaviyoCode(code));
      });

      test('$method completes when native succeeds', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (call) async {
          log.add(call);
          if (call.method == 'getCurrentGeofences') {
            return {'geofences': <Map<String, Object>>[]};
          }
          return null;
        });
        final sdk = KlaviyoSDK();
        await sdk.initialize(apiKey: 'KEY_1');

        await expectLater(invoke(sdk), completes);
        expect(log.where((c) => c.method == method), hasLength(1));
      });
    }

    test('getCurrentGeofences returns native geofences', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getCurrentGeofences') {
          return {
            'geofences': [
              {
                'identifier': 'store',
                'latitude': 42.0,
                'longitude': -71.0,
                'radius': 100,
              },
            ],
          };
        }
        return null;
      });
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      final geofences = await sdk.getCurrentGeofences();
      expect(geofences.single.identifier, 'store');
      expect(geofences.single.radius, 100.0);
    });
  });
}
