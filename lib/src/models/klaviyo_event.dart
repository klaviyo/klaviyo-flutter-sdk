import 'event_metric.dart';

/// Represents an event to be tracked in Klaviyo
class KlaviyoEvent {
  /// Name of the event. Must be less than 128 characters.
  /// Use [EventMetric] for predefined events or [EventMetric.custom] for custom event names.
  final EventMetric name;

  /// A numeric value to associate with this event.
  /// For example, the dollar amount of a purchase.
  final double? value;

  /// A unique identifier for an event.
  ///
  /// If the uniqueId is repeated for the same profile and metric, only the first
  /// processed event will be recorded. If this is not present, this will use the
  /// time to the second. Using the default, this limits only one event per profile
  /// per second.
  final String? uniqueId;

  /// Properties of this event.
  ///
  /// Any top level property (that are not objects) can be used to create segments.
  /// The $extra property is a special property. This records any non-segmentable
  /// values that can be referenced later. For example, HTML templates are useful
  /// on a segment but are not used to create a segment.
  ///
  /// There are limits placed onto the size of the data present:
  /// - Must not exceed 5 MB
  /// - Must not exceed 300 event properties
  /// - A single string cannot be larger than 100 KB
  /// - Each array must not exceed 4000 elements
  /// - The properties cannot contain more than 10 nested levels
  final Map<String, dynamic>? properties;

  /// Creates a new event with an [EventMetric].
  ///
  /// Examples:
  /// ```dart
  /// // Using predefined metric
  /// final event = KlaviyoEvent(
  ///   name: EventMetric.openedApp,
  /// );
  ///
  /// // Using custom event name with properties
  /// final customEvent = KlaviyoEvent(
  ///   name: EventMetric.custom('User Completed Tutorial'),
  ///   properties: {'tutorial_id': 'intro_v2'},
  ///   value: 10.0,
  /// );
  /// ```
  KlaviyoEvent({
    required this.name,
    this.properties,
    this.value,
    this.uniqueId,
  });

  /// Creates a new event with a custom metric name.
  ///
  /// This is a convenience constructor equivalent to:
  /// `KlaviyoEvent(name: EventMetric.custom(metric), ...)`
  ///
  /// Example:
  /// ```dart
  /// final event = KlaviyoEvent.custom(
  ///   metric: 'User Completed Tutorial',
  ///   properties: {'tutorial_id': 'intro_v2'},
  /// );
  /// ```
  KlaviyoEvent.custom({
    required String metric,
    Map<String, dynamic>? properties,
    double? value,
    String? uniqueId,
  }) : this(
          name: EventMetric.custom(metric),
          properties: properties,
          value: value,
          uniqueId: uniqueId,
        );

  /// Create a copy with updated values
  KlaviyoEvent copyWith({
    EventMetric? name,
    Map<String, dynamic>? properties,
    double? value,
    String? uniqueId,
  }) {
    return KlaviyoEvent(
      name: name ?? this.name,
      properties: properties ?? this.properties,
      value: value ?? this.value,
      uniqueId: uniqueId ?? this.uniqueId,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name.name,
    };

    if (properties != null) {
      data['properties'] = Map<String, dynamic>.from(properties!);
    }

    if (value != null) {
      data['value'] = value;
    }

    if (uniqueId != null) {
      data['unique_id'] = uniqueId;
    }

    return data;
  }

  /// Create from JSON
  factory KlaviyoEvent.fromJson(Map<String, dynamic> json) {
    return KlaviyoEvent(
      name: EventMetric.custom(json['event'] as String),
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : null,
      value: (json['value'] as num?)?.toDouble(),
      uniqueId: json['unique_id'] as String?,
    );
  }

  @override
  String toString() {
    return 'KlaviyoEvent(name: ${name.name}, properties: ${properties?.length ?? 0} items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KlaviyoEvent &&
        other.name == name &&
        other.value == value &&
        other.uniqueId == uniqueId;
  }

  @override
  int get hashCode {
    return Object.hash(name, value, uniqueId);
  }
}
