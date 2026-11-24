/// What a tap on an inbox message, or on one of its action buttons, does.
///
/// This is a raw-value type rather than a Dart enum so it mirrors the native
/// SDKs' `InboxDestinationType`: a later native release can add a destination
/// type without breaking callers, and an unrecognized value survives the trip
/// through Dart unchanged. Compare against [openApp], [deepLink] and
/// [openUrl], or switch on [rawValue].
class InboxDestinationType {
  /// The value the native SDKs use for this destination type.
  ///
  /// One of `open_app`, `deep_link` or `open_url` today, but callers must not
  /// assume that set is closed.
  final String rawValue;

  const InboxDestinationType(this.rawValue);

  /// Open the app with no further navigation. Has no URL.
  static const InboxDestinationType openApp = InboxDestinationType('open_app');

  /// Route [InboxDestination.url] through the app's deep link handling.
  static const InboxDestinationType deepLink = InboxDestinationType(
    'deep_link',
  );

  /// Open [InboxDestination.url] in the platform's external handler.
  static const InboxDestinationType openUrl = InboxDestinationType('open_url');

  @override
  String toString() => 'InboxDestinationType($rawValue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxDestinationType && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

/// Where a message, or one of its buttons, leads.
///
/// The SDK never opens a destination on its own: the host performs the
/// navigation.
class InboxDestination {
  /// What the tap does.
  final InboxDestinationType type;

  /// The destination URL. Null for [InboxDestinationType.openApp].
  final String? url;

  const InboxDestination({required this.type, this.url});

  /// Create a destination from its bridge map.
  ///
  /// Throws an [ArgumentError] when `type` is missing or not a string, because
  /// the map comes from this SDK's own native bridge rather than from an
  /// arbitrary push payload.
  factory InboxDestination.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType.isEmpty) {
      throw ArgumentError("Missing required field 'type' in inbox destination");
    }
    return InboxDestination(
      type: InboxDestinationType(rawType),
      url: map['url'] as String?,
    );
  }

  /// Convert to the bridge map shape.
  Map<String, dynamic> toMap() => {'type': type.rawValue, 'url': url};

  @override
  String toString() => 'InboxDestination(type: $type, url: $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxDestination && other.type == type && other.url == url;

  @override
  int get hashCode => Object.hash(type, url);
}
