import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('Geofence', () {
    const geofence = Geofence(
      identifier: 'store-1',
      latitude: 40.7,
      longitude: -74.0,
      radius: 100,
    );

    test('fromJson accepts ints for the numeric fields', () {
      final parsed = Geofence.fromJson({
        'identifier': 'store-1',
        'latitude': 40.7,
        'longitude': -74,
        'radius': 100,
      });

      expect(parsed, geofence);
      expect(parsed.hashCode, geofence.hashCode);
      expect(parsed.longitude, isA<double>());
      expect(parsed.radius, isA<double>());
    });

    test('round-trips through toJson', () {
      expect(Geofence.fromJson(geofence.toJson()), geofence);
    });

    test('differs when any field differs', () {
      const others = [
        Geofence(identifier: 'x', latitude: 40.7, longitude: -74, radius: 100),
        Geofence(identifier: 'store-1', latitude: 0, longitude: -74, radius: 1),
        Geofence(
          identifier: 'store-1',
          latitude: 40.7,
          longitude: 0,
          radius: 1,
        ),
        Geofence(
          identifier: 'store-1',
          latitude: 40.7,
          longitude: -74,
          radius: 1,
        ),
      ];
      for (final other in others) {
        expect(other, isNot(geofence));
      }
    });
  });

  group('KlaviyoLocation', () {
    const full = KlaviyoLocation(
      address1: '1 Main St',
      address2: 'Apt 2',
      city: 'Boston',
      country: 'US',
      region: 'MA',
      zip: '02110',
      latitude: 42.36,
      longitude: -71.06,
      timezone: 'America/New_York',
    );

    test('toJson uses the standard wire keys', () {
      expect(full.toJson(), {
        'address1': '1 Main St',
        'address2': 'Apt 2',
        'city': 'Boston',
        'country': 'US',
        'region': 'MA',
        'zip': '02110',
        'latitude': 42.36,
        'longitude': -71.06,
        'timezone': 'America/New_York',
      });
    });

    test('toJson omits null fields', () {
      expect(const KlaviyoLocation(city: 'Boston').toJson(), {
        'city': 'Boston',
      });
      expect(const KlaviyoLocation().toJson(), isEmpty);
    });

    test('round-trips through fromJson', () {
      final parsed = KlaviyoLocation.fromJson(full.toJson());
      expect(parsed, full);
      expect(parsed.hashCode, full.hashCode);
    });

    test('fromJson converts int coordinates to doubles', () {
      final parsed = KlaviyoLocation.fromJson({'latitude': 1, 'longitude': 2});
      expect(parsed.latitude, 1.0);
      expect(parsed.longitude, 2.0);
    });

    test('copyWith replaces only the given fields', () {
      final moved = full.copyWith(city: 'Cambridge', zip: '02139');

      expect(moved.city, 'Cambridge');
      expect(moved.zip, '02139');
      expect(moved.copyWith(city: 'Boston', zip: '02110'), full);
      expect(full.copyWith(), full);
    });

    test('equality considers every field', () {
      expect(full.copyWith(timezone: 'UTC'), isNot(full));
      expect(full.copyWith(latitude: 0), isNot(full));
      expect(full.copyWith(address2: 'x'), isNot(full));
    });
  });

  group('KlaviyoProfile', () {
    test('deprecated id maps to externalId, which wins when both are set', () {
      // ignore: deprecated_member_use_from_same_package
      expect(KlaviyoProfile(id: 'legacy').externalId, 'legacy');
      expect(
        // ignore: deprecated_member_use_from_same_package
        KlaviyoProfile(id: 'legacy', externalId: 'new').externalId,
        'new',
      );
    });

    test('deprecated flat location fields build a location', () {
      final profile = KlaviyoProfile(
        // ignore: deprecated_member_use_from_same_package
        address1: '1 Main St',
        // ignore: deprecated_member_use_from_same_package
        region: 'MA',
        // ignore: deprecated_member_use_from_same_package
        latitude: '42.5',
        // ignore: deprecated_member_use_from_same_package
        longitude: 'not a number',
      );

      expect(
        profile.location,
        const KlaviyoLocation(
          address1: '1 Main St',
          region: 'MA',
          latitude: 42.5,
        ),
      );
    });

    test('an explicit location wins over the flat fields', () {
      final profile = KlaviyoProfile(
        location: const KlaviyoLocation(city: 'Boston'),
        // ignore: deprecated_member_use_from_same_package
        address1: '1 Main St',
      );
      expect(profile.location, const KlaviyoLocation(city: 'Boston'));
    });

    test('no flat fields means no location', () {
      expect(KlaviyoProfile(email: 'a@b.com').location, isNull);
    });

    test('toJson writes every typed field and nests the location', () {
      final profile = KlaviyoProfile(
        email: 'a@b.com',
        phoneNumber: '+15555550100',
        externalId: 'ext-1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        organization: 'Analytical Engines',
        title: 'Engineer',
        image: 'https://example.com/a.png',
        location: const KlaviyoLocation(city: 'London'),
      );

      expect(profile.toJson(), {
        'email': 'a@b.com',
        'phone_number': '+15555550100',
        'external_id': 'ext-1',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'organization': 'Analytical Engines',
        'title': 'Engineer',
        'image': 'https://example.com/a.png',
        'location': {'city': 'London'},
      });
    });

    test('round-trips through a JSON string', () {
      final profile = KlaviyoProfile(
        email: 'a@b.com',
        phoneNumber: '+15555550100',
        externalId: 'ext-1',
        organization: 'Org',
        title: 'Title',
        image: 'img',
        location: const KlaviyoLocation(city: 'London', latitude: 51.5),
        properties: {'plan': 'gold'},
      );

      final parsed = KlaviyoProfile.fromJsonString(profile.toJsonString());

      expect(parsed, profile);
      expect(parsed.hashCode, profile.hashCode);
      expect(parsed.properties, {'plan': 'gold'});
    });

    test('copyWith replaces only the given fields', () {
      final profile = KlaviyoProfile(
        email: 'a@b.com',
        location: const KlaviyoLocation(city: 'London'),
        properties: {'plan': 'gold'},
      );

      final updated = profile.copyWith(
        phoneNumber: '+15555550100',
        externalId: 'ext-1',
        organization: 'Org',
        title: 'Title',
        image: 'img',
        location: const KlaviyoLocation(city: 'Paris'),
        properties: {'plan': 'silver'},
      );

      expect(updated.email, 'a@b.com');
      expect(updated.phoneNumber, '+15555550100');
      expect(updated.externalId, 'ext-1');
      expect(updated.organization, 'Org');
      expect(updated.title, 'Title');
      expect(updated.image, 'img');
      expect(updated.location, const KlaviyoLocation(city: 'Paris'));
      expect(updated.properties, {'plan': 'silver'});
      expect(profile.copyWith().location, profile.location);
      expect(profile.copyWith().properties, profile.properties);
    });

    test('equality considers the typed fields', () {
      final base = KlaviyoProfile(email: 'a@b.com', firstName: 'Ada');
      expect(KlaviyoProfile(email: 'a@b.com', firstName: 'Ada'), base);
      expect(base.copyWith(lastName: 'L'), isNot(base));
      expect(
        base.copyWith(location: const KlaviyoLocation(city: 'X')),
        isNot(base),
      );
    });
  });

  group('EventMetric', () {
    test('a custom metric equals the predefined one with the same name', () {
      expect(const EventMetric.custom('Opened App'), EventMetric.openedApp);
      expect(
        const EventMetric.custom('Opened App').hashCode,
        EventMetric.openedApp.hashCode,
      );
    });

    test('toString is the metric name', () {
      expect(EventMetric.startedCheckout.toString(), 'Started Checkout');
      expect(const EventMetric.custom('Mine').toString(), 'Mine');
    });
  });

  group('KlaviyoSubscription', () {
    test('equality and hashCode ignore set order', () {
      const a = KlaviyoSubscription(
        listId: 'L',
        channels: KlaviyoSubscriptionChannels(
          email: {EmailConsent.marketing, EmailConsent.openTracking},
        ),
        customSource: 'S',
      );
      const b = KlaviyoSubscription(
        listId: 'L',
        channels: KlaviyoSubscriptionChannels(
          email: {EmailConsent.openTracking, EmailConsent.marketing},
        ),
        customSource: 'S',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equality distinguishes channels, list and source', () {
      const base = KlaviyoSubscription(
        listId: 'L',
        channels:
            KlaviyoSubscriptionChannels(sms: {MessagingConsent.marketing}),
      );

      expect(
        const KlaviyoSubscription(
          listId: 'L',
          channels: KlaviyoSubscriptionChannels(
            whatsapp: {MessagingConsent.marketing},
          ),
        ),
        isNot(base),
      );
      expect(
        const KlaviyoSubscription(
          listId: 'M',
          channels: KlaviyoSubscriptionChannels(
            sms: {MessagingConsent.marketing},
          ),
        ),
        isNot(base),
      );
      expect(
        const KlaviyoSubscription.allAvailableMarketing(listId: 'L'),
        isNot(base),
      );
    });

    test('channels without any channel set cannot be serialized', () {
      expect(
        () => const KlaviyoSubscriptionChannels().toJson(),
        throwsStateError,
      );
    });

    test('allAvailableMarketing keeps the custom source', () {
      expect(
        const KlaviyoSubscription.allAvailableMarketing(
          listId: 'L',
          customSource: 'Footer',
        ).toJson(),
        {'listId': 'L', 'customSource': 'Footer'},
      );
    });
  });

  group('InAppFormConfig', () {
    test('toJson sends the timeout in whole seconds', () {
      expect(
        const InAppFormConfig(sessionTimeoutDuration: Duration(minutes: 5))
            .toJson(),
        {'sessionTimeoutDuration': 300},
      );
    });

    test('toJson sends null for the platform default', () {
      expect(const InAppFormConfig().toJson(), {
        'sessionTimeoutDuration': null,
      });
    });

    test('toJson sends -1 for an infinite timeout', () {
      expect(const InAppFormConfig.infinite().toJson(), {
        'sessionTimeoutDuration': -1,
      });
    });
  });

  group('KlaviyoPushToken', () {
    test('holds the token and its type', () {
      const token = KlaviyoPushToken(
        token: 'abc123',
        type: KlaviyoPushTokenType.apns,
      );

      expect(token.token, 'abc123');
      expect(token.type, KlaviyoPushTokenType.apns);
    });

    test('equality and hashCode consider the token and type', () {
      const base = KlaviyoPushToken(
        token: 'abc123',
        type: KlaviyoPushTokenType.apns,
      );

      expect(
        const KlaviyoPushToken(
          token: 'abc123',
          type: KlaviyoPushTokenType.apns,
        ),
        base,
      );
      expect(
        const KlaviyoPushToken(
          token: 'abc123',
          type: KlaviyoPushTokenType.apns,
        ).hashCode,
        base.hashCode,
      );
      expect(
        const KlaviyoPushToken(
          token: 'def456',
          type: KlaviyoPushTokenType.apns,
        ),
        isNot(base),
      );
      expect(
        const KlaviyoPushToken(
          token: 'abc123',
          type: KlaviyoPushTokenType.fcm,
        ),
        isNot(base),
      );
    });

    test('toString includes the token and type', () {
      const token = KlaviyoPushToken(
        token: 'abc123',
        type: KlaviyoPushTokenType.fcm,
      );

      expect(token.toString(), contains('abc123'));
      expect(token.toString(), contains('fcm'));
    });
  });

  group('KlaviyoPushTokenType', () {
    test('exposes apns and fcm with stable names', () {
      expect(KlaviyoPushTokenType.apns.name, 'apns');
      expect(KlaviyoPushTokenType.fcm.name, 'fcm');
    });

    test('fromName maps known names and keeps unknown ones', () {
      expect(KlaviyoPushTokenType.fromName('apns'), KlaviyoPushTokenType.apns);
      expect(KlaviyoPushTokenType.fromName('fcm'), KlaviyoPushTokenType.fcm);
      final other = KlaviyoPushTokenType.fromName('web');
      expect(other.name, 'web');
      expect(other, isNot(KlaviyoPushTokenType.apns));
      expect(other, isNot(KlaviyoPushTokenType.fcm));
    });

    test('equality and toString follow the sibling types', () {
      expect(
        KlaviyoPushTokenType.fromName('apns'),
        KlaviyoPushTokenType.apns,
      );
      expect(
        KlaviyoPushTokenType.apns.hashCode,
        KlaviyoPushTokenType.fromName('apns').hashCode,
      );
      expect(
        KlaviyoPushTokenType.fcm.toString(),
        'KlaviyoPushTokenType(fcm)',
      );
    });
  });
}
