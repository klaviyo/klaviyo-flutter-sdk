/// Maps lowercased camelCase and snake_case spellings of standard Klaviyo
/// profile attributes to the canonical key sent over the platform channel.
const Map<String, String> _standardProfileKeys = {
  'firstname': 'first_name',
  'first_name': 'first_name',
  'lastname': 'last_name',
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
  'time_zone': 'timezone',
};

/// Returns the canonical snake_case key for a standard profile attribute
/// (case-insensitive, camelCase or snake_case), or [key] unchanged if it is
/// not a standard attribute.
String normalizeProfileKey(String key) =>
    _standardProfileKeys[key.toLowerCase()] ?? key;

/// Returns a copy of [properties] with every key passed through
/// [normalizeProfileKey].
Map<String, dynamic> normalizeProfileProperties(
  Map<String, dynamic> properties,
) =>
    properties.map((key, value) => MapEntry(normalizeProfileKey(key), value));
