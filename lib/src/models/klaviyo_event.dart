import 'dart:convert';

/// Represents an event to be tracked in Klaviyo
class KlaviyoEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? customerProperties;
  final double? value;
  final String? uniqueId;

  const KlaviyoEvent({
    required this.name,
    required this.properties,
    required this.timestamp,
    this.customerProperties,
    this.value,
    this.uniqueId,
  });

  /// Create a copy with updated values
  KlaviyoEvent copyWith({
    String? name,
    Map<String, dynamic>? properties,
    DateTime? timestamp,
    String? customerProperties,
    double? value,
    String? uniqueId,
  }) {
    return KlaviyoEvent(
      name: name ?? this.name,
      properties: properties ?? this.properties,
      timestamp: timestamp ?? this.timestamp,
      customerProperties: customerProperties ?? this.customerProperties,
      value: value ?? this.value,
      uniqueId: uniqueId ?? this.uniqueId,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'properties': Map<String, dynamic>.from(properties),
      'time': timestamp.toIso8601String(),
    };

    if (customerProperties != null) {
      data['customer_properties'] = customerProperties;
    }

    if (value != null) {
      data['properties']['value'] = value;
    }

    if (uniqueId != null) {
      data['unique_id'] = uniqueId;
    }

    return data;
  }

  /// Create from JSON
  factory KlaviyoEvent.fromJson(Map<String, dynamic> json) {
    return KlaviyoEvent(
      name: json['event'] as String,
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      timestamp: DateTime.parse(json['time'] as String),
      customerProperties: json['customer_properties'] as String?,
      value: (json['properties']?['value'] as num?)?.toDouble(),
      uniqueId: json['unique_id'] as String?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory KlaviyoEvent.fromJsonString(String jsonString) {
    return KlaviyoEvent.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'KlaviyoEvent(name: $name, timestamp: $timestamp, properties: ${properties.length} items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoEvent &&
        other.name == name &&
        other.timestamp == timestamp &&
        other.customerProperties == customerProperties &&
        other.value == value &&
        other.uniqueId == uniqueId;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      timestamp,
      customerProperties,
      value,
      uniqueId,
    );
  }
}
