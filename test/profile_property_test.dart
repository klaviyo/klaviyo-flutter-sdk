import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('ProfileProperty', () {
    const expected = {
      ProfileProperty.firstName: 'first_name',
      ProfileProperty.lastName: 'last_name',
      ProfileProperty.organization: 'organization',
      ProfileProperty.title: 'title',
      ProfileProperty.image: 'image',
      ProfileProperty.address1: 'address1',
      ProfileProperty.address2: 'address2',
      ProfileProperty.city: 'city',
      ProfileProperty.country: 'country',
      ProfileProperty.region: 'region',
      ProfileProperty.zip: 'zip',
      ProfileProperty.latitude: 'latitude',
      ProfileProperty.longitude: 'longitude',
      ProfileProperty.timezone: 'timezone',
    };

    for (final entry in expected.entries) {
      test('${entry.value} constant matches its wire key', () {
        expect(entry.key, entry.value);
      });
    }

    test('defines 14 distinct keys', () {
      expect(expected.length, 14);
    });
  });
}
