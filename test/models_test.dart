import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

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

    test('fromJson throws when a field is missing', () {
      expect(
        () => Geofence.fromJson({'identifier': 'x', 'latitude': 1}),
        throwsA(isA<TypeError>()),
      );
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

    test('toString names every field', () {
      expect(
        geofence.toString(),
        'Geofence(identifier: store-1, latitude: 40.7, longitude: -74.0, '
        'radius: 100.0)',
      );
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

    test('copyWith can set every field', () {
      final built = const KlaviyoLocation().copyWith(
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
      expect(built, full);
    });

    test('equality considers every field', () {
      expect(full.copyWith(timezone: 'UTC'), isNot(full));
      expect(full.copyWith(latitude: 0), isNot(full));
      expect(full.copyWith(address2: 'x'), isNot(full));
    });

    test('toString shows city, country and coordinates', () {
      expect(
        full.toString(),
        'KlaviyoLocation(city: Boston, country: US, lat: 42.36, lng: -71.06)',
      );
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

    test('toString shows the identifiers only', () {
      expect(
        KlaviyoProfile(email: 'a@b.com', firstName: 'Ada').toString(),
        'KlaviyoProfile(email: a@b.com, phoneNumber: null, externalId: null)',
      );
    });
  });

  group('KlaviyoEvent', () {
    test('fromJson reads every field', () {
      final event = KlaviyoEvent.fromJson({
        'name': 'Viewed Product',
        'properties': {'sku': 'A1'},
        'value': 3,
        'value_currency': 'USD',
        'unique_id': 'u-1',
      });

      expect(event.name, EventMetric.viewedProduct);
      expect(event.properties, {'sku': 'A1'});
      expect(event.value, 3.0);
      expect(event.uniqueId, 'u-1');
    });

    test('toString reports the property count', () {
      expect(
        KlaviyoEvent.custom(metric: 'X', properties: {'a': 1, 'b': 2})
            .toString(),
        'KlaviyoEvent(name: X, properties: 2 items)',
      );
      expect(
        KlaviyoEvent.custom(metric: 'X').toString(),
        'KlaviyoEvent(name: X, properties: 0 items)',
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

    test('predefined metrics have distinct names', () {
      expect(
        {
          EventMetric.openedApp,
          EventMetric.viewedProduct,
          EventMetric.addedToCart,
          EventMetric.startedCheckout,
        },
        hasLength(4),
      );
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

    test('toString names list, channels and source', () {
      const subscription = KlaviyoSubscription(
        listId: 'L',
        channels:
            KlaviyoSubscriptionChannels(sms: {MessagingConsent.marketing}),
      );
      expect(subscription.toString(), contains('listId: L'));
      expect(subscription.toString(), contains('customSource: null'));
      expect(
        subscription.channels.toString(),
        contains('sms: {MessagingConsent.marketing}'),
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

    test('fromJson reads each form of the timeout', () {
      final infinite = InAppFormConfig.fromJson({'sessionTimeoutDuration': -1});
      expect(infinite.isInfinite, isTrue);
      expect(infinite.sessionTimeoutDuration, isNull);

      final timed = InAppFormConfig.fromJson({'sessionTimeoutDuration': 30});
      expect(timed.isInfinite, isFalse);
      expect(timed.sessionTimeoutDuration, const Duration(seconds: 30));

      final fallback = InAppFormConfig.fromJson({});
      expect(fallback.isInfinite, isFalse);
      expect(fallback.sessionTimeoutDuration, isNull);

      expect(
        InAppFormConfig.fromJson({'sessionTimeoutDuration': '30'})
            .sessionTimeoutDuration,
        isNull,
      );
    });

    test('a zero timeout round-trips as zero, not as the default', () {
      final parsed = InAppFormConfig.fromJson(
        const InAppFormConfig(sessionTimeoutDuration: Duration.zero).toJson(),
      );
      expect(parsed.sessionTimeoutDuration, Duration.zero);
    });

    test('copyWith can switch to infinite and to a new timeout', () {
      const config =
          InAppFormConfig(sessionTimeoutDuration: Duration(hours: 1));

      expect(config.copyWith(isInfinite: true).isInfinite, isTrue);
      expect(
        config
            .copyWith(sessionTimeoutDuration: const Duration(minutes: 1))
            .sessionTimeoutDuration,
        const Duration(minutes: 1),
      );
      expect(
        config.copyWith().sessionTimeoutDuration,
        const Duration(hours: 1),
      );
    });

    test('toString reports the timeout', () {
      expect(
        const InAppFormConfig.infinite().toString(),
        'InAppFormConfig(sessionTimeoutDuration: infinite)',
      );
      expect(
        const InAppFormConfig(sessionTimeoutDuration: Duration(seconds: 90))
            .toString(),
        'InAppFormConfig(sessionTimeoutDuration: 0:01:30.000000)',
      );
    });
  });

  group('FormLifecycleEvent', () {
    test('FormShown and FormDismissed compare by value', () {
      const shown = FormShown(formId: 'f', formName: 'n');
      const dismissed = FormDismissed(formId: 'f', formName: 'n');

      expect(const FormShown(formId: 'f', formName: 'n'), shown);
      expect(const FormShown(formId: 'g', formName: 'n'), isNot(shown));
      expect(const FormDismissed(formId: 'f', formName: 'n'), dismissed);
      expect(const FormDismissed(formId: 'f', formName: 'm'), isNot(dismissed));
      expect(
        const FormDismissed(formId: 'f', formName: 'n').hashCode,
        dismissed.hashCode,
      );
    });
  });

  group('KlaviyoLogLevel', () {
    test('maps each level to a package:logging level', () {
      expect(
        {for (final level in KlaviyoLogLevel.values) level: level.toLevel()},
        {
          KlaviyoLogLevel.none: Level.OFF,
          KlaviyoLogLevel.error: Level.SEVERE,
          KlaviyoLogLevel.warning: Level.WARNING,
          KlaviyoLogLevel.info: Level.INFO,
          KlaviyoLogLevel.debug: Level.FINE,
          KlaviyoLogLevel.verbose: Level.FINER,
        },
      );
    });

    test('round-trips through its string form, ignoring case', () {
      for (final level in KlaviyoLogLevel.values) {
        expect(KlaviyoLogLevel.fromString(level.toString()), level);
        expect(
          KlaviyoLogLevel.fromString(level.toString().toUpperCase()),
          level,
        );
      }
    });

    test('an unknown string falls back to info', () {
      expect(KlaviyoLogLevel.fromString('loud'), KlaviyoLogLevel.info);
    });
  });

  group('exceptions', () {
    test('KlaviyoException toString includes the code when set', () {
      expect(
        const KlaviyoException('boom').toString(),
        'KlaviyoException: boom',
      );
      expect(
        const KlaviyoException('boom', code: 'X').toString(),
        'KlaviyoException: boom (Code: X)',
      );
    });

    test('subclasses carry their error codes', () {
      final cases = <KlaviyoException, String>{
        const KlaviyoNotInitializedException(): 'NOT_INITIALIZED',
        const KlaviyoInvalidApiKeyException(): 'INVALID_API_KEY',
        const KlaviyoNetworkException('n'): 'NETWORK_ERROR',
        const KlaviyoProfileException('p'): 'PROFILE_ERROR',
        const KlaviyoEventException('e'): 'EVENT_ERROR',
        const KlaviyoPushException('p'): 'PUSH_ERROR',
        const KlaviyoFormException('f'): 'FORM_ERROR',
        const KlaviyoConfigurationException('c'): 'CONFIGURATION_ERROR',
        const KlaviyoPermissionException('p'): 'PERMISSION_ERROR',
      };
      cases.forEach((exception, code) {
        expect(exception.code, code, reason: exception.runtimeType.toString());
      });
    });

    test('default messages describe the failure', () {
      expect(
        const KlaviyoNotInitializedException().message,
        'Klaviyo SDK is not initialized',
      );
      expect(
        const KlaviyoInvalidApiKeyException().message,
        'Invalid or missing API key',
      );
    });

    test('KlaviyoNetworkException toString includes the status code', () {
      expect(
        const KlaviyoNetworkException('down', statusCode: 503).toString(),
        'KlaviyoNetworkException: down (Status: 503)',
      );
      expect(
        const KlaviyoNetworkException('down').toString(),
        'KlaviyoNetworkException: down',
      );
    });
  });
}
