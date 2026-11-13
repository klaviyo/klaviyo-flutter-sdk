import 'package:logging/logging.dart';

import '../models/profile_property.dart';
import 'channel_value_sanitizer.dart';
import 'profile_key_normalizer.dart';

const String _propertiesKey = 'properties';
const String _locationKey = 'location';

final Logger _logger = Logger('KlaviyoSDK');

/// Wire keys of the profile identifiers.
abstract final class ProfileIdentifierKey {
  static const String email = 'email';
  static const String phoneNumber = 'phone_number';
  static const String externalId = 'external_id';

  static const Set<String> all = {email, phoneNumber, externalId};
}

const Set<String> _topLevelStringKeys = {
  ...ProfileIdentifierKey.all,
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

bool _isStandardKey(String key) =>
    _topLevelStringKeys.contains(key) ||
    _locationStringKeys.contains(key) ||
    _locationNumberKeys.contains(key);

/// Converts [value] to the type the native SDKs expect for [key].
///
/// [key] must already be normalized. For latitude and longitude, a number or
/// numeric string becomes a [double], and any other value can't be converted.
/// For other identifier and standard attribute keys, a [num] or [bool]
/// becomes a [String]. Other values, and values for custom keys, are returned
/// unchanged. Returns null when [value] is null or can't be converted.
Object? coerceProfileValue(String key, Object? value) {
  if (value == null) return null;
  if (_locationNumberKeys.contains(key)) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  if (_isStandardKey(key) && (value is num || value is bool)) {
    return value.toString();
  }
  return value;
}

Object? _coerceOrWarn(String source, String key, Object? value) {
  final coerced = coerceProfileValue(key, value);
  if (coerced == null && value != null) {
    _logger.warning(
      "$source: dropping '$key' because its ${value.runtimeType} value "
      "can't be converted for this attribute",
    );
  }
  return coerced;
}

/// The result of [splitProfileProperties].
class ProfilePropertiesUpdate {
  const ProfilePropertiesUpdate(this.identifiers, this.properties);

  /// Identifier values keyed by [ProfileIdentifierKey].
  final Map<String, String> identifiers;

  /// Normalized and coerced properties for `setProfileProperties`.
  final Map<String, dynamic> properties;
}

/// Prepares a `setProfileProperties` map for the platform channel.
///
/// Values are first passed through [sanitizeChannelProperties]. Keys are
/// then normalized with [normalizeProfileProperties]. The identifier keys
/// `email`, `phone_number` and `external_id` (matched exactly) are moved to
/// [ProfilePropertiesUpdate.identifiers]. Standard attribute values are
/// converted with [coerceProfileValue], and entries whose value is null, or
/// can't be converted, are dropped.
ProfilePropertiesUpdate splitProfileProperties(
  Map<String, dynamic> properties,
) {
  final identifiers = <String, String>{};
  final remaining = <String, dynamic>{};
  normalizeProfileProperties(
    sanitizeChannelProperties(properties, source: 'setProfileProperties'),
  ).forEach((key, value) {
    final coerced = _coerceOrWarn('setProfileProperties', key, value);
    if (coerced == null) return;
    if (ProfileIdentifierKey.all.contains(key) && coerced is String) {
      identifiers[key] = coerced;
    } else {
      remaining[key] = coerced;
    }
  });
  return ProfilePropertiesUpdate(identifiers, remaining);
}

/// Returns the `setProfile` payload for [profileJson], the output of
/// `KlaviyoProfile.toJson`.
///
/// `properties` values are first passed through [sanitizeChannelProperties].
/// Standard attribute keys inside `properties` are matched as
/// [normalizeProfileKey] matches them. The identifier keys `email`,
/// `phone_number` and `external_id` are matched exactly. Each one is converted
/// with [coerceProfileValue] and fills the matching typed field (or `location`
/// field) only when that field is unset. A value that loses to a typed field
/// is logged as a warning. Either way the key is removed from `properties`.
/// Other keys stay in `properties` as custom properties, except those whose
/// value is null.
Map<String, dynamic> resolveProfilePayload(Map<String, dynamic> profileJson) {
  final payload = Map<String, dynamic>.from(profileJson);
  final rawProperties = payload[_propertiesKey];
  if (rawProperties is! Map) return payload;

  final location = payload[_locationKey] is Map
      ? Map<String, dynamic>.from(payload[_locationKey] as Map)
      : <String, dynamic>{};
  final custom = <String, dynamic>{};

  normalizeProfileProperties(
    sanitizeChannelProperties(
      Map<String, dynamic>.from(rawProperties),
      source: 'setProfile',
    ),
  ).forEach((key, value) {
    if (_topLevelStringKeys.contains(key)) {
      _fillIfUnset(payload, key, _coerceOrWarn('setProfile', key, value));
    } else if (_locationStringKeys.contains(key) ||
        _locationNumberKeys.contains(key)) {
      _fillIfUnset(location, key, _coerceOrWarn('setProfile', key, value));
    } else if (value != null) {
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
  if (value == null) return;
  final existing = target[key];
  if (existing == null) {
    target[key] = value;
  } else if (existing != value) {
    _logger.warning(
      "setProfile: ignoring properties['$key'] because the typed field "
      'is already set',
    );
  }
}
