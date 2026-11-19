import 'dart:convert';
import 'klaviyo_location.dart';
import 'profile_property.dart';

/// Represents a user profile in Klaviyo
class KlaviyoProfile {
  final String? email;
  final String? phoneNumber;
  final String? externalId;
  final String? firstName;
  final String? lastName;
  final String? organization;
  final String? title;
  final String? image;
  final KlaviyoLocation? location;

  /// Custom profile properties.
  ///
  /// Keys for identifiers (`email`, `phone_number`, `external_id`) and
  /// standard attributes (see [ProfileProperty]) are used only when the
  /// matching typed field is null, and are never sent as custom properties.
  /// Entries with a null value are ignored and don't clear a property.
  /// [DateTime] values, including nested ones, are sent as UTC ISO 8601
  /// strings. Values the platform channel can't encode, such as [Duration],
  /// [Uri] or custom classes, are dropped with a warning and the rest of the
  /// profile is still sent.
  final Map<String, dynamic>? properties;

  /// Creates a new [KlaviyoProfile].
  ///
  /// The [id], [address1], [address2], [region], [latitude], and [longitude]
  /// parameters are provided for migration from the `klaviyo_flutter` community
  /// package and are deprecated. Use [externalId] and [location] instead.
  ///
  /// If both [externalId] and [id] are provided, [externalId] takes precedence.
  /// If both [location] and any flat location fields are provided, [location]
  /// takes precedence.
  KlaviyoProfile({
    this.email,
    this.phoneNumber,
    String? externalId,
    @Deprecated(
      'Use externalId instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? id,
    this.firstName,
    this.lastName,
    this.organization,
    this.title,
    this.image,
    KlaviyoLocation? location,
    this.properties,
    @Deprecated(
      'Use location: KlaviyoLocation(address1: ...) instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? address1,
    @Deprecated(
      'Use location: KlaviyoLocation(address2: ...) instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? address2,
    @Deprecated(
      'Use location: KlaviyoLocation(region: ...) instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? region,
    @Deprecated(
      'Use location: KlaviyoLocation(latitude: ...) instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? latitude,
    @Deprecated(
      'Use location: KlaviyoLocation(longitude: ...) instead. '
      'Provided for migration from klaviyo_flutter. '
      'Will be removed in 2.0.',
    )
    String? longitude,
  })  : externalId = externalId ?? id,
        location = location ??
            ((address1 ?? address2 ?? region ?? latitude ?? longitude) != null
                ? KlaviyoLocation(
                    address1: address1,
                    address2: address2,
                    region: region,
                    latitude:
                        latitude != null ? double.tryParse(latitude) : null,
                    longitude:
                        longitude != null ? double.tryParse(longitude) : null,
                  )
                : null);

  /// Create a copy of this profile with updated values
  KlaviyoProfile copyWith({
    String? email,
    String? phoneNumber,
    String? externalId,
    String? firstName,
    String? lastName,
    String? organization,
    String? title,
    String? image,
    KlaviyoLocation? location,
    Map<String, dynamic>? properties,
  }) {
    return KlaviyoProfile(
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      externalId: externalId ?? this.externalId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      organization: organization ?? this.organization,
      title: title ?? this.title,
      image: image ?? this.image,
      location: location ?? this.location,
      properties: properties ?? this.properties,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (email != null) data['email'] = email;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (externalId != null) data['external_id'] = externalId;
    if (firstName != null) data[ProfileProperty.firstName] = firstName;
    if (lastName != null) data[ProfileProperty.lastName] = lastName;
    if (organization != null) data[ProfileProperty.organization] = organization;
    if (title != null) data[ProfileProperty.title] = title;
    if (image != null) data[ProfileProperty.image] = image;
    if (location != null) data['location'] = location!.toJson();

    if (properties != null && properties!.isNotEmpty) {
      data['properties'] = Map<String, dynamic>.from(properties!);
    }

    return data;
  }

  static const _knownJsonKeys = {
    'email',
    'phone_number',
    'external_id',
    ProfileProperty.firstName,
    ProfileProperty.lastName,
    ProfileProperty.organization,
    ProfileProperty.title,
    ProfileProperty.image,
    'location',
  };

  /// Create from JSON
  factory KlaviyoProfile.fromJson(Map<String, dynamic> json) {
    // Extract known fields
    final email = json['email'] as String?;
    final phoneNumber = json['phone_number'] as String?;
    final externalId = json['external_id'] as String?;
    final firstName = json[ProfileProperty.firstName] as String?;
    final lastName = json[ProfileProperty.lastName] as String?;
    final organization = json[ProfileProperty.organization] as String?;
    final title = json[ProfileProperty.title] as String?;
    final image = json[ProfileProperty.image] as String?;

    KlaviyoLocation? location;
    if (json['location'] != null) {
      location = KlaviyoLocation.fromJson(json['location']);
    }

    final Map<String, dynamic>? properties;
    final nestedProperties = json['properties'];
    if (nestedProperties is Map) {
      properties = nestedProperties.isNotEmpty
          ? Map<String, dynamic>.from(nestedProperties)
          : null;
    } else {
      // Pre-0.6.0 toJson wrote custom properties at the top level.
      final legacy = Map<String, dynamic>.from(json)
        ..removeWhere((key, value) => _knownJsonKeys.contains(key));
      properties = legacy.isNotEmpty ? legacy : null;
    }

    return KlaviyoProfile(
      email: email,
      phoneNumber: phoneNumber,
      externalId: externalId,
      firstName: firstName,
      lastName: lastName,
      organization: organization,
      title: title,
      image: image,
      location: location,
      properties: properties,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory KlaviyoProfile.fromJsonString(String jsonString) {
    return KlaviyoProfile.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'KlaviyoProfile(email: $email, phoneNumber: $phoneNumber, externalId: $externalId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoProfile &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.externalId == externalId &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.organization == organization &&
        other.title == title &&
        other.image == image &&
        other.location == location;
  }

  @override
  int get hashCode {
    return Object.hash(
      email,
      phoneNumber,
      externalId,
      firstName,
      lastName,
      organization,
      title,
      image,
      location,
    );
  }
}
