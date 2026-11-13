import '../models/profile_property.dart';
import 'profile_key_normalizer.dart';

const String _propertiesKey = 'properties';
const String _locationKey = 'location';

const Set<String> _topLevelStringKeys = {
  'email',
  'phone_number',
  'external_id',
  ProfileProperty.firstName,
  ProfileProperty.lastName,
  ProfileProperty.organization,
  ProfileProperty.title,
  ProfileProperty.image,
};

const Set<String> _locationStringKeys = {
  ProfileProperty.address1,
  ProfileProperty.address2,
  ProfileProperty.city,
  ProfileProperty.country,
  ProfileProperty.region,
  ProfileProperty.zip,
  ProfileProperty.timezone,
};

const Set<String> _locationNumberKeys = {
  ProfileProperty.latitude,
  ProfileProperty.longitude,
};

/// Returns the `setProfile` payload for [profileJson], the output of
/// `KlaviyoProfile.toJson`.
///
/// Standard attribute keys inside `properties` are matched as
/// [normalizeProfileKey] matches them. The identifier keys `email`,
/// `phone_number` and `external_id` are matched exactly. Each one fills the
/// matching typed field (or `location` field) only when that field is unset,
/// and is removed from `properties`. Other keys stay in `properties` as
/// custom properties.
Map<String, dynamic> resolveProfilePayload(Map<String, dynamic> profileJson) {
  final payload = Map<String, dynamic>.from(profileJson);
  final rawProperties = payload[_propertiesKey];
  if (rawProperties is! Map) return payload;

  final location = payload[_locationKey] is Map
      ? Map<String, dynamic>.from(payload[_locationKey] as Map)
      : <String, dynamic>{};
  final custom = <String, dynamic>{};

  normalizeProfileProperties(Map<String, dynamic>.from(rawProperties))
      .forEach((key, value) {
    if (_topLevelStringKeys.contains(key)) {
      _fillIfUnset(payload, key, _asString(value));
    } else if (_locationStringKeys.contains(key)) {
      _fillIfUnset(location, key, _asString(value));
    } else if (_locationNumberKeys.contains(key)) {
      _fillIfUnset(location, key, _asDouble(value));
    } else {
      custom[key] = value;
    }
  });

  if (location.isNotEmpty) payload[_locationKey] = location;
  if (custom.isNotEmpty) {
    payload[_propertiesKey] = custom;
  } else {
    payload.remove(_propertiesKey);
  }
  return payload;
}

void _fillIfUnset(Map<String, dynamic> target, String key, Object? value) {
  if (value != null && target[key] == null) target[key] = value;
}

String? _asString(Object? value) => value?.toString();

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
