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

  group('KlaviyoSDK.setProfile', () {
    test('sends custom properties nested under properties', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          email: 'test@example.com',
          externalId: 'ext-123',
          properties: {'plan': 'premium', 'age': 25},
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'email': 'test@example.com',
          'external_id': 'ext-123',
          'properties': {'plan': 'premium', 'age': 25},
        },
      });
    });

    test('omits properties when none are set', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(KlaviyoProfile(email: 'test@example.com'));

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {'email': 'test@example.com'},
      });
    });

    test('promotes standard keys in properties to standard fields', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          email: 'test@example.com',
          properties: {
            'first_name': 'Ada',
            'lastName': 'Lovelace',
            'ORGANIZATION': 'Analytical Engines',
            'plan': 'premium',
          },
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'email': 'test@example.com',
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'organization': 'Analytical Engines',
          'properties': {'plan': 'premium'},
        },
      });
    });

    test('typed fields win over the same key in properties', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          firstName: 'A',
          properties: {'first_name': 'B', 'firstName': 'C'},
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {'first_name': 'A'},
      });
    });

    test('promotes location keys in properties into location', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          location: const KlaviyoLocation(city: 'Boston'),
          properties: {
            'city': 'Cambridge',
            'zip': '02139',
            'address_1': '1 Main St',
            'latitude': 42,
          },
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'location': {
            'city': 'Boston',
            'zip': '02139',
            'address1': '1 Main St',
            'latitude': 42.0,
          },
        },
      });
    });

    test('promotes snake_case identifiers in properties', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          email: 'typed@example.com',
          properties: {
            'email': 'nested@example.com',
            'phone_number': '+15555550100',
            'external_id': 'ext-1',
            'phoneNumber': '+15555550199',
          },
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'email': 'typed@example.com',
          'phone_number': '+15555550100',
          'external_id': 'ext-1',
          'properties': {'phoneNumber': '+15555550199'},
        },
      });
    });

    test('warns when a typed field wins over a properties key', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      final records = <LogRecord>[];
      final sub = Logger('KlaviyoSDK').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await sdk.setProfile(
        KlaviyoProfile(
          firstName: 'A',
          location: const KlaviyoLocation(city: 'Boston'),
          properties: {'first_name': 'B', 'city': 'Cambridge', 'zip': '02139'},
        ),
      );

      final warnings = records
          .where((r) => r.level == Level.WARNING)
          .map((r) => r.message)
          .toList();
      expect(warnings, hasLength(2));
      expect(
        warnings.where((m) => m.contains("properties['first_name']")),
        hasLength(1),
      );
      expect(
        warnings.where((m) => m.contains("properties['city']")),
        hasLength(1),
      );
    });

    test('coerces standard values and drops nulls in properties', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          properties: {
            'first_name': 5,
            'longitude': '-71.1',
            'plan': null,
            'visits': 3,
          },
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'first_name': '5',
          'location': {'longitude': -71.1},
          'properties': {'visits': 3},
        },
      });
    });

    test('passes custom keys through untouched', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfile(
        KlaviyoProfile(
          properties: {
            'plan': 'premium',
            'Favorite_Color': 'blue',
            'prefs': {'push': true},
          },
        ),
      );

      final call = log.singleWhere((c) => c.method == 'setProfile');
      expect(call.arguments, {
        'profile': {
          'properties': {
            'plan': 'premium',
            'Favorite_Color': 'blue',
            'prefs': {'push': true},
          },
        },
      });
    });
  });

  group('KlaviyoSDK.setProfileProperties', () {
    test('normalizes standard keys to snake_case', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfileProperties({
        'firstName': 'Ada',
        'LastName': 'Lovelace',
        'address_1': '1 Main St',
        'address2': 'Apt 2',
        'timeZone': 'America/New_York',
        'favoriteColor': 'blue',
      });

      final call = log.singleWhere((c) => c.method == 'setProfileProperties');
      expect(call.arguments['properties'], {
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'address1': '1 Main St',
        'address2': 'Apt 2',
        'timezone': 'America/New_York',
        'favoriteColor': 'blue',
      });
    });

    test('setProfileAttribute normalizes a camelCase key', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfileAttribute('firstName', 'Ada');

      final call = log.singleWhere((c) => c.method == 'setProfileProperties');
      expect(call.arguments['properties'], {'first_name': 'Ada'});
    });

    test('setProfileAttribute with ProfileProperty sends the wire key',
        () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfileAttribute(ProfileProperty.firstName, 'Ada');

      final call = log.singleWhere((c) => c.method == 'setProfileProperties');
      expect(call.arguments['properties'], {'first_name': 'Ada'});
    });

    test('routes identifier keys to the identifier setters', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      log.clear();

      await sdk.setProfileProperties({
        'email': 'ada@example.com',
        'phone_number': '+15555550100',
        'external_id': 'ext-1',
        'plan': 'premium',
      });

      expect(log.map((c) => c.method), [
        'setEmail',
        'setPhoneNumber',
        'setExternalId',
        'setProfileProperties',
      ]);
      expect(log[0].arguments, {'email': 'ada@example.com'});
      expect(log[1].arguments, {'phoneNumber': '+15555550100'});
      expect(log[2].arguments, {'externalId': 'ext-1'});
      expect(log[3].arguments['properties'], {'plan': 'premium'});
    });

    test('setProfileAttribute with email only calls setEmail', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      log.clear();

      await sdk.setProfileAttribute('email', 'ada@example.com');

      expect(log.map((c) => c.method), ['setEmail']);
      expect(log.single.arguments, {'email': 'ada@example.com'});
    });

    test('identifier keys match exactly', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      log.clear();

      await sdk.setProfileProperties({
        'phoneNumber': '+15555550100',
        'Email': 'ada@example.com',
      });

      expect(log.map((c) => c.method), ['setProfileProperties']);
      expect(log.single.arguments['properties'], {
        'phoneNumber': '+15555550100',
        'Email': 'ada@example.com',
      });
    });

    test('coerces standard attribute values', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');

      await sdk.setProfileProperties({
        'first_name': 5,
        'zip': 2139,
        'latitude': 42,
        'longitude': '-71.1',
        'external_id': 12345,
        'visits': 3,
      });

      final ids = log.singleWhere((c) => c.method == 'setExternalId');
      expect(ids.arguments, {'externalId': '12345'});
      final call = log.singleWhere((c) => c.method == 'setProfileProperties');
      expect(call.arguments['properties'], {
        'first_name': '5',
        'zip': '2139',
        'latitude': 42.0,
        'longitude': -71.1,
        'visits': 3,
      });
    });

    test('drops and warns on values that cannot be coerced', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      final records = <LogRecord>[];
      final sub = Logger('KlaviyoSDK').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await sdk.setProfileProperties({'latitude': 'north', 'plan': 'premium'});

      final call = log.singleWhere((c) => c.method == 'setProfileProperties');
      expect(call.arguments['properties'], {'plan': 'premium'});
      expect(
        records.where(
          (r) => r.level == Level.WARNING && r.message.contains("'latitude'"),
        ),
        hasLength(1),
      );
    });

    test('drops null values', () async {
      final sdk = KlaviyoSDK();
      await sdk.initialize(apiKey: 'KEY_1');
      log.clear();

      await sdk.setProfileProperties({
        'plan': null,
        'first_name': null,
        'email': null,
        'visits': 3,
      });
      await sdk.setProfileAttribute('plan', null);

      expect(log.map((c) => c.method), ['setProfileProperties']);
      expect(log.single.arguments['properties'], {'visits': 3});
    });
  });
}
