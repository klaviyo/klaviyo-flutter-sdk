import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/src/utils/profile_key_normalizer.dart';

void main() {
  group('normalizeProfileKey', () {
    const expected = {
      'firstName': 'first_name',
      'first_name': 'first_name',
      'lastName': 'last_name',
      'last_name': 'last_name',
      'organization': 'organization',
      'title': 'title',
      'image': 'image',
      'address1': 'address1',
      'address_1': 'address1',
      'address2': 'address2',
      'address_2': 'address2',
      'city': 'city',
      'country': 'country',
      'region': 'region',
      'zip': 'zip',
      'latitude': 'latitude',
      'longitude': 'longitude',
      'timezone': 'timezone',
      'timeZone': 'timezone',
      'time_zone': 'timezone',
    };

    for (final entry in expected.entries) {
      test('maps ${entry.key} to ${entry.value}', () {
        expect(normalizeProfileKey(entry.key), entry.value);
      });
    }

    test('is case-insensitive for standard keys', () {
      expect(normalizeProfileKey('FIRST_NAME'), 'first_name');
      expect(normalizeProfileKey('FirstName'), 'first_name');
    });

    test('leaves unknown keys unchanged', () {
      expect(normalizeProfileKey('parity_plain'), 'parity_plain');
      expect(normalizeProfileKey('favoriteColor'), 'favoriteColor');
    });
  });

  test('normalizeProfileProperties preserves values', () {
    final nested = {'notifications': true};
    expect(
      normalizeProfileProperties({
        'firstName': 'Ada',
        'latitude': 40.7,
        'preferences': nested,
      }),
      {
        'first_name': 'Ada',
        'latitude': 40.7,
        'preferences': nested,
      },
    );
  });
}
