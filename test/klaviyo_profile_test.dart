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

      expect(json, {
        'email': 'test@example.com',
        'properties': {'custom_field': 'custom_value', 'age': 25},
      });
    });

    test('toJson omits properties when null', () {
      final json = KlaviyoProfile(email: 'test@example.com').toJson();

      expect(json.containsKey('properties'), isFalse);
    });

    test('toJson omits properties when empty', () {
      final json = KlaviyoProfile(
        email: 'test@example.com',
        properties: {},
      ).toJson();

      expect(json.containsKey('properties'), isFalse);
    });

    test('fromJson reads an empty nested properties map as null', () {
      final profile = KlaviyoProfile.fromJson({
        'email': 'test@example.com',
        'properties': <String, dynamic>{},
      });

      expect(profile.properties, isNull);
    });

    test('fromJson reads nested properties', () {
      final profile = KlaviyoProfile.fromJson({
        'email': 'test@example.com',
        'properties': {'custom_field': 'custom_value', 'age': 25},
      });

      expect(profile.email, 'test@example.com');
      expect(profile.properties, {'custom_field': 'custom_value', 'age': 25});
    });

    test('fromJson leaves properties null when absent', () {
      final profile = KlaviyoProfile.fromJson({'email': 'test@example.com'});

      expect(profile.properties, isNull);
    });

    test('fromJson reads top-level properties from the pre-0.6.0 shape', () {
      final profile = KlaviyoProfile.fromJson({
        'email': 'test@example.com',
        'first_name': 'Jane',
        'custom_field': 'custom_value',
        'age': 25,
      });

      expect(profile.email, 'test@example.com');
      expect(profile.firstName, 'Jane');
      expect(profile.properties, {'custom_field': 'custom_value', 'age': 25});
      expect(profile.toJson()['properties'], {
        'custom_field': 'custom_value',
        'age': 25,
      });
    });

    test('fromJson keeps a legacy scalar property named properties', () {
      final profile = KlaviyoProfile.fromJson({
        'email': 'test@example.com',
        'properties': 'rental',
        'age': 25,
      });

      expect(profile.properties, {'properties': 'rental', 'age': 25});
    });

    test('fromJson ignores top-level keys when nested properties exist', () {
      final profile = KlaviyoProfile.fromJson({
        'email': 'test@example.com',
        'stray': 'value',
        'properties': {'custom_field': 'custom_value'},
      });

      expect(profile.properties, {'custom_field': 'custom_value'});
    });

    test('toJson and fromJson round-trip properties', () {
      final original = KlaviyoProfile(
        email: 'test@example.com',
        properties: {'custom_field': 'custom_value', 'age': 25},
      );

      final restored = KlaviyoProfile.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.properties, original.properties);
    });
  });
}
