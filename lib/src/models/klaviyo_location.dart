import 'profile_property.dart';

/// Represents a geographic location for user profiles
final class KlaviyoLocation {
  /// First line of street address.
  final String? address1;

  /// Second line of street address.
  final String? address2;

  /// City name.
  final String? city;

  /// Country name.
  final String? country;

  /// Region within a country, such as state or province.
  final String? region;

  /// Zip code.
  final String? zip;

  /// Latitude coordinate. We recommend providing a precision of four decimal
  /// places.
  final double? latitude;

  /// Longitude coordinate. We recommend providing a precision of four decimal
  /// places.
  final double? longitude;

  /// Time zone name. We recommend using time zones from the IANA Time Zone
  /// Database.
  final String? timezone;

  /// Creates a location. Every field is optional.
  const KlaviyoLocation({
    this.address1,
    this.address2,
    this.city,
    this.country,
    this.region,
    this.zip,
    this.latitude,
    this.longitude,
    this.timezone,
  });

  /// Create a copy with updated values
  KlaviyoLocation copyWith({
    String? address1,
    String? address2,
    String? city,
    String? country,
    String? region,
    String? zip,
    double? latitude,
    double? longitude,
    String? timezone,
  }) {
    return KlaviyoLocation(
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      country: country ?? this.country,
      region: region ?? this.region,
      zip: zip ?? this.zip,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (address1 != null) data[ProfileProperty.address1] = address1;
    if (address2 != null) data[ProfileProperty.address2] = address2;
    if (city != null) data[ProfileProperty.city] = city;
    if (country != null) data[ProfileProperty.country] = country;
    if (region != null) data[ProfileProperty.region] = region;
    if (zip != null) data[ProfileProperty.zip] = zip;
    if (latitude != null) data[ProfileProperty.latitude] = latitude;
    if (longitude != null) data[ProfileProperty.longitude] = longitude;
    if (timezone != null) data[ProfileProperty.timezone] = timezone;

    return data;
  }

  /// Create from JSON
  factory KlaviyoLocation.fromJson(Map<String, dynamic> json) {
    return KlaviyoLocation(
      address1: json[ProfileProperty.address1] as String?,
      address2: json[ProfileProperty.address2] as String?,
      city: json[ProfileProperty.city] as String?,
      country: json[ProfileProperty.country] as String?,
      region: json[ProfileProperty.region] as String?,
      zip: json[ProfileProperty.zip] as String?,
      latitude: (json[ProfileProperty.latitude] as num?)?.toDouble(),
      longitude: (json[ProfileProperty.longitude] as num?)?.toDouble(),
      timezone: json[ProfileProperty.timezone] as String?,
    );
  }

  @override
  String toString() {
    return 'KlaviyoLocation(city: $city, country: $country, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoLocation &&
        other.address1 == address1 &&
        other.address2 == address2 &&
        other.city == city &&
        other.country == country &&
        other.region == region &&
        other.zip == zip &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timezone == timezone;
  }

  @override
  int get hashCode {
    return Object.hash(
      address1,
      address2,
      city,
      country,
      region,
      zip,
      latitude,
      longitude,
      timezone,
    );
  }
}
