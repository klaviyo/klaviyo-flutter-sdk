import 'inbox_destination.dart';

/// A button on an inbox message.
class InboxAction {
  /// Identifies the selected button for metrics.
  final String id;

  /// The user-visible label of the button.
  final String label;

  /// Where tapping the button leads.
  final InboxDestination destination;

  const InboxAction({
    required this.id,
    required this.label,
    required this.destination,
  });

  /// Create an action from its bridge map.
  ///
  /// Throws an [ArgumentError] when a required field is missing, because the
  /// map comes from this SDK's own native bridge rather than from an arbitrary
  /// push payload.
  factory InboxAction.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError("Missing required field 'id' in inbox action");
    }

    final destination = map['destination'];
    if (destination is! Map) {
      throw ArgumentError(
        "Missing required field 'destination' in inbox action",
      );
    }

    return InboxAction(
      id: id,
      label: (map['label'] as String?) ?? '',
      destination: InboxDestination.fromMap(
        Map<String, dynamic>.from(destination),
      ),
    );
  }

  /// Convert to the bridge map shape.
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'destination': destination.toMap(),
      };

  @override
  String toString() =>
      'InboxAction(id: $id, label: $label, destination: $destination)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxAction &&
          other.id == id &&
          other.label == label &&
          other.destination == destination;

  @override
  int get hashCode => Object.hash(id, label, destination);
}
