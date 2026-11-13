import '../models/profile_property.dart';

/// Maps lowercased camelCase and snake_case spellings of standard Klaviyo
/// profile attributes to the canonical key sent over the platform channel.
const Map<String, String> _standardProfileKeys = {
  'firstname': ProfileProperty.firstName,
  'first_name': ProfileProperty.firstName,
  'lastname': ProfileProperty.lastName,
  'last_name': ProfileProperty.lastName,
  'organization': ProfileProperty.organization,
  'title': ProfileProperty.title,
  'image': ProfileProperty.image,
  'address1': ProfileProperty.address1,
  'address_1': ProfileProperty.address1,
  'address2': ProfileProperty.address2,
  'address_2': ProfileProperty.address2,
  'city': ProfileProperty.city,
  'country': ProfileProperty.country,
  'region': ProfileProperty.region,
  'zip': ProfileProperty.zip,
  'latitude': ProfileProperty.latitude,
  'longitude': ProfileProperty.longitude,
  'timezone': ProfileProperty.timezone,
  'time_zone': ProfileProperty.timezone,
};

/// Returns the canonical snake_case key for a standard profile attribute
/// (case-insensitive, camelCase or snake_case), or [key] unchanged if it is
/// not a standard attribute.
String normalizeProfileKey(String key) =>
    _standardProfileKeys[key.toLowerCase()] ?? key;

/// Returns a copy of [properties] with every key passed through
/// [normalizeProfileKey].
///
/// When several keys normalize to the same key, the last non-null value wins.
Map<String, dynamic> normalizeProfileProperties(
  Map<String, dynamic> properties,
) {
  final normalized = <String, dynamic>{};
  properties.forEach((key, value) {
    final normalizedKey = normalizeProfileKey(key);
    if (value == null && normalized[normalizedKey] != null) return;
    normalized[normalizedKey] = value;
  });
  return normalized;
}
