import 'package:flutter_test/flutter_test.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() {
  group('KlaviyoProfile', () {
    test('creates profile with basic properties', () {
      final profile = KlaviyoProfile(
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
      );

      expect(profile.email, 'test@example.com');
      expect(profile.firstName, 'John');
      expect(profile.lastName, 'Doe');
    });

    test('toJson converts profile to map', () {
      final profile = KlaviyoProfile(
        email: 'test@example.com',
        firstName: 'John',
        phoneNumber: '+1234567890',
      );

      final json = profile.toJson();

      expect(json['email'], 'test@example.com');
      expect(json['first_name'], 'John');
      expect(json['phone_number'], '+1234567890');
    });

    test('fromJson creates profile from map', () {
      final json = {
        'email': 'test@example.com',
        'first_name': 'Jane',
        'last_name': 'Smith',
      };

      final profile = KlaviyoProfile.fromJson(json);

      expect(profile.email, 'test@example.com');
      expect(profile.firstName, 'Jane');
      expect(profile.lastName, 'Smith');
    });

    test('copyWith creates new profile with updated values', () {
      final original = KlaviyoProfile(
        email: 'test@example.com',
        firstName: 'John',
      );

      final updated = original.copyWith(firstName: 'Jane', lastName: 'Doe');

      expect(updated.email, 'test@example.com');
      expect(updated.firstName, 'Jane');
      expect(updated.lastName, 'Doe');
      expect(original.firstName, 'John'); // Original unchanged
    });

    test('toJson includes custom properties', () {
      final profile = KlaviyoProfile(
        email: 'test@example.com',
        properties: {'custom_field': 'custom_value', 'age': 25},
      );

      final json = profile.toJson();

      expect(json['email'], 'test@example.com');
      expect(json['custom_field'], 'custom_value');
      expect(json['age'], 25);
    });
  });
}
