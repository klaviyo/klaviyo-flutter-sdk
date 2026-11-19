import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('KlaviyoSDK before initialize', () {
    final sdk = KlaviyoSDK();
    final guarded = <String, Future<Object?> Function()>{
      'setProfile': () => sdk.setProfile(KlaviyoProfile(email: 'a@b.com')),
      'setEmail': () => sdk.setEmail('a@b.com'),
      'setPhoneNumber': () => sdk.setPhoneNumber('+1'),
      'setExternalId': () => sdk.setExternalId('x'),
      'getEmail': sdk.getEmail,
      'getPhoneNumber': sdk.getPhoneNumber,
      'getExternalId': sdk.getExternalId,
      'setProfileProperties': () => sdk.setProfileProperties({'a': 1}),
      'createEvent': () => sdk.createEvent(KlaviyoEvent.custom(metric: 'X')),
      'createSubscription': () => sdk.createSubscription(
            const KlaviyoSubscription.allAvailableMarketing(listId: 'L'),
          ),
      'registerForPushNotifications': sdk.registerForPushNotifications,
      'setPushToken': () => sdk.setPushToken('t'),
      'getPushToken': sdk.getPushToken,
      'registerForInAppForms': sdk.registerForInAppForms,
      'unregisterFromInAppForms': sdk.unregisterFromInAppForms,
      'startFormsPreview': () => sdk.startFormsPreview('t'),
      'endFormsPreview': sdk.endFormsPreview,
      'registerAuthTokenProvider': () =>
          sdk.registerAuthTokenProvider(() async => 'jwt'),
      'unregisterAuthTokenProvider': sdk.unregisterAuthTokenProvider,
      'registerGeofencing': sdk.registerGeofencing,
      'unregisterGeofencing': sdk.unregisterGeofencing,
      'getCurrentGeofences': sdk.getCurrentGeofences,
      'resetProfile': sdk.resetProfile,
    };

    guarded.forEach((name, call) {
      test('$name throws and makes no native call', () async {
        await expectLater(call(), throwsA(isA<KlaviyoException>()));
        expect(log, isEmpty);
      });
    });

    test('getters report the uninitialized state', () {
      expect(sdk.isInitialized, isFalse);
      expect(sdk.apiKey, isNull);
    });
  });

  group('KlaviyoNativeWrapper before initialize', () {
    final wrapper = KlaviyoNativeWrapper();

    test('throws KlaviyoNotInitializedException for guarded calls', () async {
      expect(wrapper.isInitialized, isFalse);
      expect(wrapper.apiKey, isNull);
      await expectLater(
        wrapper.registerAuthTokenProvider(),
        throwsA(isA<KlaviyoException>()),
      );
      await expectLater(
        wrapper.respondToAuthTokenRequest('id', jwt: 'jwt'),
        throwsA(isA<KlaviyoException>()),
      );
      await expectLater(
        wrapper.setBadgeCount(1),
        throwsA(isA<KlaviyoNotInitializedException>()),
      );
      expect(log, isEmpty);
    });
  });
}
