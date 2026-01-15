import 'dart:convert';
import 'klaviyo_location.dart';

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
  final Map<String, dynamic>? properties;

  const KlaviyoProfile({
    this.email,
    this.phoneNumber,
    this.externalId,
    this.firstName,
    this.lastName,
    this.organization,
    this.title,
    this.image,
    this.location,
    this.properties,
  });

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
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (organization != null) data['organization'] = organization;
    if (title != null) data['title'] = title;
    if (image != null) data['image'] = image;
    if (location != null) data['location'] = location!.toJson();

    // Merge custom properties
    if (properties != null) {
      data.addAll(properties!);
    }

    return data;
  }

  /// Create from JSON
  factory KlaviyoProfile.fromJson(Map<String, dynamic> json) {
    // Extract known fields
    final email = json['email'] as String?;
    final phoneNumber = json['phone_number'] as String?;
    final externalId = json['external_id'] as String?;
    final firstName = json['first_name'] as String?;
    final lastName = json['last_name'] as String?;
    final organization = json['organization'] as String?;
    final title = json['title'] as String?;
    final image = json['image'] as String?;

    KlaviyoLocation? location;
    if (json['location'] != null) {
      location = KlaviyoLocation.fromJson(json['location']);
    }

    // Extract custom properties (exclude known fields)
    final Map<String, dynamic> properties = Map.from(json);
    properties.removeWhere(
      (key, value) => [
        'email',
        'phone_number',
        'external_id',
        'first_name',
        'last_name',
        'organization',
        'title',
        'image',
        'location',
      ].contains(key),
    );

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
      properties: properties.isNotEmpty ? properties : null,
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
