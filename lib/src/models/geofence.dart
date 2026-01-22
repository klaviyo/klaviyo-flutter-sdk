/// Represents a geographic region being monitored by the Klaviyo SDK
///
/// A geofence defines a circular region using a center point (latitude/longitude)
/// and radius in meters. The SDK can monitor when users enter or exit these regions.
class Geofence {
  /// Unique identifier for this geofence
  final String identifier;

  /// Latitude of the geofence center point
  final double latitude;

  /// Longitude of the geofence center point
  final double longitude;

  /// Radius of the geofence in meters
  final double radius;

  const Geofence({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  /// Create a Geofence from JSON
  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      identifier: json['identifier'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      radius: json['radius'] as double,
    );
  }

  /// Convert Geofence to JSON
  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  @override
  String toString() {
    return 'Geofence(identifier: $identifier, latitude: $latitude, longitude: $longitude, radius: $radius)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Geofence &&
        other.identifier == identifier &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radius == radius;
  }

  @override
  int get hashCode {
    return identifier.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        radius.hashCode;
  }
}
