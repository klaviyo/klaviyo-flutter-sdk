/// Represents a geographic location for user profiles
class KlaviyoLocation {
  final String? address1;
  final String? address2;
  final String? city;
  final String? country;
  final String? region;
  final String? zip;
  final double? latitude;
  final double? longitude;
  final String? timezone;

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
    
    if (address1 != null) data['address1'] = address1;
    if (address2 != null) data['address2'] = address2;
    if (city != null) data['city'] = city;
    if (country != null) data['country'] = country;
    if (region != null) data['region'] = region;
    if (zip != null) data['zip'] = zip;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (timezone != null) data['timezone'] = timezone;
    
    return data;
  }

  /// Create from JSON
  factory KlaviyoLocation.fromJson(Map<String, dynamic> json) {
    return KlaviyoLocation(
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      region: json['region'] as String?,
      zip: json['zip'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
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