import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  const eventChannel = EventChannel('klaviyo_events');

  final log = <MethodCall>[];
  final responses = <String, Object? Function(MethodCall)>{};
  final warnings = <String>[];

  final sdk = KlaviyoSDK();

  void failOn(String method) {
    responses[method] = (_) => throw PlatformException(
          code: 'NATIVE_ERROR',
          message: 'native failure',
        );
  }

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    Logger('KlaviyoSDK').onRecord.listen((record) {
      if (record.level == Level.WARNING) warnings.add(record.message);
    });
  });

  setUp(() async {
    log.clear();
    responses.clear();
    warnings.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      final respond = responses[call.method];
      return respond == null ? null : respond(call);
    });
    await sdk.initialize(apiKey: 'KEY');
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  MethodCall single(String method) =>
      log.singleWhere((c) => c.method == method);

  group('identifiers', () {
    test('setters forward the value under the native argument name', () async {
      await sdk.setEmail('a@b.com');
      await sdk.setPhoneNumber('+15555550100');
      await sdk.setExternalId('ext-1');

      expect(single('setEmail').arguments, {'email': 'a@b.com'});
      expect(single('setPhoneNumber').arguments, {
        'phoneNumber': '+15555550100',
      });
      expect(single('setExternalId').arguments, {'externalId': 'ext-1'});
    });

    test('getters return the native values', () async {
      responses['getEmail'] = (_) => 'a@b.com';
      responses['getPhoneNumber'] = (_) => '+15555550100';
      responses['getExternalId'] = (_) => 'ext-1';

      expect(await sdk.getEmail(), 'a@b.com');
      expect(await sdk.getPhoneNumber(), '+15555550100');
      expect(await sdk.getExternalId(), 'ext-1');
    });

    test('getters return null when native has no value', () async {
      expect(await sdk.getEmail(), isNull);
      expect(await sdk.getPhoneNumber(), isNull);
      expect(await sdk.getExternalId(), isNull);
    });

    for (final method in [
      'setEmail',
      'setPhoneNumber',
      'setExternalId',
      'getEmail',
      'getPhoneNumber',
      'getExternalId',
    ]) {
      test('$method wraps a native failure in KlaviyoException', () async {
        failOn(method);
        final Future<Object?> call = switch (method) {
          'setEmail' => sdk.setEmail('a@b.com'),
          'setPhoneNumber' => sdk.setPhoneNumber('+15555550100'),
          'setExternalId' => sdk.setExternalId('ext-1'),
          'getEmail' => sdk.getEmail(),
          'getPhoneNumber' => sdk.getPhoneNumber(),
          _ => sdk.getExternalId(),
        };
        await expectLater(call, throwsA(isA<KlaviyoException>()));
      });
    }

    test('setProfile wraps a native failure in KlaviyoException', () async {
      failOn('setProfile');
      await expectLater(
        sdk.setProfile(KlaviyoProfile(email: 'a@b.com')),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('setProfileProperties wraps a native failure', () async {
      failOn('setProfileProperties');
      await expectLater(
        sdk.setProfileProperties({'plan': 'gold'}),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('setProfileProperties sends nothing for an empty map', () async {
      await sdk.setProfileProperties({});
      expect(log, isEmpty);
    });

    test('setProfileProperties sends identifiers and properties together',
        () async {
      await sdk.setProfileProperties({
        'external_id': 'ext-1',
        'phone_number': '+15555550100',
        'plan': 'gold',
      });

      expect(log.map((c) => c.method), [
        'setPhoneNumber',
        'setExternalId',
        'setProfileProperties',
      ]);
      expect(single('setProfileProperties').arguments, {
        'properties': {'plan': 'gold'},
      });
    });

    test('resetProfile forwards to native', () async {
      await sdk.resetProfile();
      expect(log.map((c) => c.method), ['resetProfile']);
    });

    test('resetProfile wraps a native failure', () async {
      failOn('resetProfile');
      await expectLater(
        sdk.resetProfile(),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });

  group('createEvent', () {
    test('sends the event json', () async {
      await sdk.createEvent(
        KlaviyoEvent(
          name: EventMetric.addedToCart,
          properties: const {'sku': 'A1'},
          value: 9.5,
          valueCurrency: 'USD',
          uniqueId: 'u-1',
        ),
      );

      expect(single('trackEvent').arguments, {
        'event': {
          'name': 'Added to Cart',
          'properties': {'sku': 'A1'},
          'value': 9.5,
          'value_currency': 'USD',
          'unique_id': 'u-1',
        },
      });
    });

    test('wraps a native failure in KlaviyoException', () async {
      failOn('trackEvent');
      await expectLater(
        sdk.createEvent(KlaviyoEvent.custom(metric: 'Test')),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('wrapper track builds a custom event', () async {
      await KlaviyoNativeWrapper().track('Signed Up', {'source': 'app'});

      expect(single('trackEvent').arguments, {
        'event': {
          'name': 'Signed Up',
          'properties': {'source': 'app'},
        },
      });
    });
  });

  group('push', () {
    test('registerForPushNotifications forwards to native', () async {
      await sdk.registerForPushNotifications();
      expect(log.map((c) => c.method), ['registerForPushNotifications']);
    });

    test('setPushToken sends the token', () async {
      await sdk.setPushToken('tok');
      expect(single('setPushToken').arguments, {'token': 'tok'});
    });

    test('getPushToken returns the native token', () async {
      responses['getPushToken'] = (_) => 'tok';
      expect(await sdk.getPushToken(), 'tok');
    });

    test('push methods surface native failures as KlaviyoException', () async {
      failOn('registerForPushNotifications');
      failOn('setPushToken');
      failOn('getPushToken');

      await expectLater(
        sdk.registerForPushNotifications(),
        throwsA(isA<KlaviyoException>()),
      );
      await expectLater(
        sdk.setPushToken('tok'),
        throwsA(isA<KlaviyoException>()),
      );
      await expectLater(
        sdk.getPushToken(),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('setBadgeCount is a warning-only no-op off iOS', () async {
      sdk.setBadgeCount(3);
      await pumpEventQueue();

      expect(log, isEmpty);
      expect(warnings, contains(contains('unsupported on Android')));
    });
  });

  group('in-app forms', () {
    test('registerForInAppForms sends the configuration', () async {
      await sdk.registerForInAppForms(
        configuration: const InAppFormConfig(
          sessionTimeoutDuration: Duration(minutes: 2),
        ),
      );
      expect(single('registerForInAppForms').arguments, {
        'configuration': {'sessionTimeoutDuration': 120},
      });
    });

    test('registerForInAppForms sends a null configuration by default',
        () async {
      await sdk.registerForInAppForms();
      expect(single('registerForInAppForms').arguments, {
        'configuration': null,
      });
    });

    test('registerForInAppForms sends -1 for an infinite timeout', () async {
      await sdk.registerForInAppForms(
        configuration: const InAppFormConfig.infinite(),
      );
      expect(single('registerForInAppForms').arguments, {
        'configuration': {'sessionTimeoutDuration': -1},
      });
    });

    test('unregisterFromInAppForms forwards to native', () async {
      await sdk.unregisterFromInAppForms();
      expect(log.map((c) => c.method), ['unregisterFromInAppForms']);
    });

    for (final method in [
      'registerForInAppForms',
      'unregisterFromInAppForms',
      'startFormsPreview',
      'endFormsPreview',
    ]) {
      test('$method logs a native failure instead of throwing', () async {
        failOn(method);
        final Future<void> call = switch (method) {
          'registerForInAppForms' => sdk.registerForInAppForms(),
          'unregisterFromInAppForms' => sdk.unregisterFromInAppForms(),
          'startFormsPreview' => sdk.startFormsPreview('token'),
          _ => sdk.endFormsPreview(),
        };
        await expectLater(call, completes);
        expect(warnings, hasLength(1));
      });
    }

    test('a failed startFormsPreview does not log the token', () async {
      const token = 'secret-preview-token-value';
      responses['startFormsPreview'] = (_) => throw PlatformException(
            code: 'FORMS_ERROR',
            message: 'bad token $token',
          );

      await sdk.startFormsPreview(token);

      expect(warnings, hasLength(1));
      expect(warnings.single, isNot(contains(token)));
    });
  });

  group('geofencing', () {
    test('register and unregister forward to native', () async {
      await sdk.registerGeofencing();
      await sdk.unregisterGeofencing();
      expect(
        log.map((c) => c.method),
        ['registerGeofencing', 'unregisterGeofencing'],
      );
    });

    test('register and unregister log native failures', () async {
      failOn('registerGeofencing');
      failOn('unregisterGeofencing');

      await expectLater(sdk.registerGeofencing(), completes);
      await expectLater(sdk.unregisterGeofencing(), completes);
      expect(warnings, hasLength(2));
    });

    test('getCurrentGeofences parses the native list', () async {
      responses['getCurrentGeofences'] = (_) => {
            'geofences': [
              {
                'identifier': 'store-1',
                'latitude': 40.7,
                'longitude': -74,
                'radius': 100,
              },
            ],
          };

      expect(await sdk.getCurrentGeofences(), [
        const Geofence(
          identifier: 'store-1',
          latitude: 40.7,
          longitude: -74,
          radius: 100,
        ),
      ]);
    });

    test('getCurrentGeofences returns an empty list on failure', () async {
      failOn('getCurrentGeofences');
      expect(await sdk.getCurrentGeofences(), isEmpty);
      expect(warnings, hasLength(1));
    });

    test('getCurrentGeofences returns an empty list for a malformed payload',
        () async {
      responses['getCurrentGeofences'] = (_) => {'geofences': 'nope'};
      expect(await sdk.getCurrentGeofences(), isEmpty);
    });
  });

  group('handleUniversalTrackingLink', () {
    test('accepts a tracking link and forwards it to native', () async {
      responses['handleUniversalTrackingLink'] = (_) => true;

      expect(
        sdk.handleUniversalTrackingLink('https://trk.example.com/u/abc'),
        isTrue,
      );
      await pumpEventQueue();

      expect(single('handleUniversalTrackingLink').arguments, {
        'url': 'https://trk.example.com/u/abc',
      });
      expect(warnings, isEmpty);
    });

    for (final url in [
      '',
      '   ',
      'http://trk.example.com/u/abc',
      'https://trk.example.com/x/abc',
      'https://trk.example.com',
      'myapp://u/abc',
    ]) {
      test('rejects "$url" without calling native', () async {
        expect(sdk.handleUniversalTrackingLink(url), isFalse);
        await pumpEventQueue();
        expect(log, isEmpty);
        expect(warnings, hasLength(1));
      });
    }

    test('logs when native rejects the link', () async {
      responses['handleUniversalTrackingLink'] = (_) => false;

      expect(
        sdk.handleUniversalTrackingLink('https://trk.example.com/u/abc'),
        isTrue,
      );
      await pumpEventQueue();

      expect(warnings, [contains('rejected by native SDK')]);
    });

    test('logs a native failure instead of throwing', () async {
      failOn('handleUniversalTrackingLink');

      expect(
        sdk.handleUniversalTrackingLink('https://trk.example.com/u/abc'),
        isTrue,
      );
      await pumpEventQueue();

      expect(warnings, [contains('Failed to handle universal tracking link')]);
    });

    test('a null native result counts as a rejection', () async {
      expect(
        await KlaviyoNativeWrapper()
            .handleUniversalTrackingLink('https://trk.example.com/u/abc'),
        isFalse,
      );
    });
  });

  group('logging', () {
    tearDown(() async {
      sdk.setLogLevel(KlaviyoLogLevel.info);
      await sdk.setLoggingEnabled(true);
    });

    test('setLogLevel changes which Dart logs are emitted', () async {
      sdk.setLogLevel(KlaviyoLogLevel.error);
      expect(Logger('KlaviyoSDK').level, Level.SEVERE);

      await sdk.registerGeofencing();
      failOn('registerGeofencing');
      await sdk.registerGeofencing();
      expect(warnings, isEmpty);
    });

    test('setLogLevel while disabled applies once logging is re-enabled',
        () async {
      await sdk.setLoggingEnabled(false);
      sdk.setLogLevel(KlaviyoLogLevel.debug);
      expect(Logger('KlaviyoSDK').level, Level.OFF);

      await sdk.setLoggingEnabled(true);
      expect(Logger('KlaviyoSDK').level, Level.FINE);
    });

    test('isLoggingEnabled defaults to true when native returns null',
        () async {
      expect(await sdk.isLoggingEnabled(), isTrue);
    });

    test('isLoggingEnabled wraps a native failure', () async {
      failOn('isLoggingEnabled');
      await expectLater(
        sdk.isLoggingEnabled(),
        throwsA(isA<KlaviyoException>()),
      );
    });
  });

  group('auth token provider', () {
    test('a failed registration throws and leaves no provider', () async {
      failOn('registerAuthTokenProvider');

      await expectLater(
        sdk.registerAuthTokenProvider(() async => 'jwt'),
        throwsA(isA<KlaviyoException>()),
      );

      responses.clear();
      log.clear();
      await sdk.registerAuthTokenProvider(() async => 'jwt');
      expect(
        log.map((c) => c.method),
        ['registerAuthTokenProvider'],
        reason: 'no previous provider should need tearing down',
      );
      await sdk.unregisterAuthTokenProvider();
    });

    test('unregister wraps a native failure', () async {
      failOn('unregisterAuthTokenProvider');
      await expectLater(
        sdk.unregisterAuthTokenProvider(),
        throwsA(isA<KlaviyoException>()),
      );
    });

    test('re-registration survives a failed teardown of the old provider',
        () async {
      await sdk.registerAuthTokenProvider(() async => 'jwt-1');
      failOn('unregisterAuthTokenProvider');

      await expectLater(
        sdk.registerAuthTokenProvider(() async => 'jwt-2'),
        completes,
      );
      expect(warnings, [contains('Failed to tear down')]);

      responses.clear();
      await sdk.unregisterAuthTokenProvider();
    });
  });
}
