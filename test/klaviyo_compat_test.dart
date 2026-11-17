// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('klaviyo_sdk');
  final log = <MethodCall>[];
  final klaviyo = Klaviyo.instance;

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      log.add(call);
      return switch (call.method) {
        'getEmail' => 'a@b.com',
        'getPhoneNumber' => '+15555550100',
        'getExternalId' => 'ext-1',
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('initialize forwards the key and is shared with KlaviyoSDK', () async {
    await klaviyo.initialize('KEY');

    expect(klaviyo.isInitialized, isTrue);
    expect(KlaviyoSDK().apiKey, 'KEY');
    expect(log.single.arguments, {'apiKey': 'KEY'});
    expect(identical(Klaviyo.instance, klaviyo), isTrue);
  });

  test('logEvent sends a custom event and returns an empty string', () async {
    expect(await klaviyo.logEvent('Viewed', {'id': 1}), '');
    expect(log.single.arguments, {
      'event': {
        'name': 'Viewed',
        'properties': {'id': 1},
      },
    });
  });

  test('identifier methods forward to the matching native calls', () async {
    await klaviyo.setEmail('a@b.com');
    await klaviyo.setPhoneNumber('+15555550100');
    await klaviyo.setExternalId('ext-1');
    expect(await klaviyo.getEmail(), 'a@b.com');
    expect(await klaviyo.getPhoneNumber(), '+15555550100');
    expect(await klaviyo.getExternalId(), 'ext-1');
    await klaviyo.resetProfile();

    expect(log.map((c) => c.method), [
      'setEmail',
      'setPhoneNumber',
      'setExternalId',
      'getEmail',
      'getPhoneNumber',
      'getExternalId',
      'resetProfile',
    ]);
  });

  test('updateProfile sends the profile and returns an empty string', () async {
    expect(await klaviyo.updateProfile(KlaviyoProfile(email: 'a@b.com')), '');
    expect(log.single.method, 'setProfile');
    expect(log.single.arguments['profile']['email'], 'a@b.com');
  });

  test('attribute setters send standard keys with the given values', () async {
    await klaviyo.setFirstName('Ada');
    await klaviyo.setLastName('Lovelace');
    await klaviyo.setOrganization('Org');
    await klaviyo.setTitle('Title');
    await klaviyo.setImage('img');
    await klaviyo.setAddress1('1 Main St');
    await klaviyo.setAddress2('Apt 2');
    await klaviyo.setCity('Boston');
    await klaviyo.setCountry('US');
    await klaviyo.setLatitude(42.5);
    await klaviyo.setLongitude(-71.5);
    await klaviyo.setRegion('MA');
    await klaviyo.setZip('02110');
    await klaviyo.setTimezone('UTC');
    await klaviyo.setCustomAttribute('plan', 'gold');

    expect(
      log.map((c) => c.arguments['properties']),
      [
        {'first_name': 'Ada'},
        {'last_name': 'Lovelace'},
        {'organization': 'Org'},
        {'title': 'Title'},
        {'image': 'img'},
        {'address1': '1 Main St'},
        {'address2': 'Apt 2'},
        {'city': 'Boston'},
        {'country': 'US'},
        {'latitude': 42.5},
        {'longitude': -71.5},
        {'region': 'MA'},
        {'zip': '02110'},
        {'timezone': 'UTC'},
        {'plan': 'gold'},
      ],
    );
  });

  test('sendTokenToKlaviyo sets the push token', () async {
    await klaviyo.sendTokenToKlaviyo('tok');
    expect(log.single.method, 'setPushToken');
    expect(log.single.arguments, {'token': 'tok'});
  });

  test('handlePush is a no-op that returns true', () async {
    expect(await klaviyo.handlePush({'_k': 'x'}), isTrue);
    expect(log, isEmpty);
  });

  test('setBadgeCount completes without a native call off iOS', () async {
    await klaviyo.setBadgeCount(1);
    expect(log, isEmpty);
  });

  group('isKlaviyoPush', () {
    test('detects the tracking key at the top level (Android)', () {
      expect(klaviyo.isKlaviyoPush({'_k': '{}'}), isTrue);
      expect({'_k': '{}'}.isKlaviyoNotification, isTrue);
    });

    test('detects the tracking key inside body (iOS)', () {
      expect(
        klaviyo.isKlaviyoPush({
          'body': {'_k': '{}'},
        }),
        isTrue,
      );
    });

    test('rejects payloads without the tracking key', () {
      expect(klaviyo.isKlaviyoPush({}), isFalse);
      expect(klaviyo.isKlaviyoPush({'body': 'text with _k'}), isFalse);
      expect(
        klaviyo.isKlaviyoPush({
          'body': {'k': 1},
        }),
        isFalse,
      );
    });
  });
}
