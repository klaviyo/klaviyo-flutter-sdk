/// Keys for Klaviyo's standard profile attributes.
///
/// Pass these to [KlaviyoSDK.setProfileAttribute] or as keys of the map given
/// to [KlaviyoSDK.setProfileProperties]. Any other string key is stored as a
/// custom property.
///
/// ```dart
/// await KlaviyoSDK().setProfileAttribute(ProfileProperty.firstName, 'Jane');
/// ```
abstract final class ProfileProperty {
  /// Individual's first name
  static const String firstName = 'first_name';

  /// Individual's last name
  static const String lastName = 'last_name';

  /// Name of the company or organization within the company for whom the
  /// individual works
  static const String organization = 'organization';

  /// Individual's job title
  static const String title = 'title';

  /// URL pointing to the location of a profile image
  static const String image = 'image';

  /// First line of street address
  static const String address1 = 'address1';

  /// Second line of street address
  static const String address2 = 'address2';

  /// City name
  static const String city = 'city';

  /// Country name
  static const String country = 'country';

  /// Region within a country, such as state or province
  static const String region = 'region';

  /// Zip code
  static const String zip = 'zip';

  /// Latitude coordinate. We recommend providing a precision of four decimal
  /// places.
  static const String latitude = 'latitude';

  /// Longitude coordinate. We recommend providing a precision of four decimal
  /// places.
  static const String longitude = 'longitude';

  /// Time zone name. We recommend using time zones from the IANA Time Zone
  /// Database.
  ///
  /// On iOS this key is stored as a custom property. Use
  /// [KlaviyoLocation.timezone] with [KlaviyoSDK.setProfile] to set the
  /// profile's timezone on both platforms.
  static const String timezone = 'timezone';
}
