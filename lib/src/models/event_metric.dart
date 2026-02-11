/// EventMetric represents the name of an event that can be tracked.
///
/// Use predefined metrics for common events, or create custom metrics
/// with the [EventMetric.custom] constructor.
///
sealed class EventMetric {
  /// The name of this event metric
  final String name;

  const EventMetric._(this.name);

  /// Creates a custom event metric with the given name
  const factory EventMetric.custom(String name) = CustomEventMetric;

  /// The 'Opened App' event is used to track when a user opens the app.
  static const EventMetric openedApp = _PredefinedEventMetric('Opened App');

  /// The 'Viewed Product' event is used to track when a user views a product.
  static const EventMetric viewedProduct =
      _PredefinedEventMetric('Viewed Product');

  /// The 'Added to Cart' event is used to track when a user adds a product to their cart.
  static const EventMetric addedToCart =
      _PredefinedEventMetric('Added to Cart');

  /// The 'Started Checkout' event is used to track when a user starts the checkout process.
  static const EventMetric startedCheckout =
      _PredefinedEventMetric('Started Checkout');

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventMetric && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

/// Predefined event metric
final class _PredefinedEventMetric extends EventMetric {
  const _PredefinedEventMetric(super.name) : super._();
}

/// Custom event metric with a user-defined name
final class CustomEventMetric extends EventMetric {
  /// Creates a custom event metric with the given [name]
  const CustomEventMetric(super.name) : super._();
}
