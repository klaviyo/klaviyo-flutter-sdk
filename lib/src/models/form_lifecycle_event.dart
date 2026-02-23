/// Enum representing the type of form lifecycle event
enum FormLifecycleEventType {
  /// Form was shown/presented to the user
  formShown('form_shown'),

  /// Form was dismissed by the user
  formDismissed('form_dismissed'),

  /// Form CTA was clicked
  formCtaClicked('form_cta_clicked');

  final String value;
  const FormLifecycleEventType(this.value);

  /// Parse event type from string
  static FormLifecycleEventType fromString(String value) {
    return FormLifecycleEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid event type: $value'),
    );
  }
}

/// Data class representing a form lifecycle event
class FormLifecycleEvent {
  /// The type of lifecycle event
  final FormLifecycleEventType eventType;

  /// Optional form ID (available on Android)
  final String? formId;

  const FormLifecycleEvent({
    required this.eventType,
    this.formId,
  });

  /// Create a FormLifecycleEvent from a map received from the event channel
  factory FormLifecycleEvent.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? {};
    final eventString = data['event'] as String;

    return FormLifecycleEvent(
      eventType: FormLifecycleEventType.fromString(eventString),
      formId: data['formId'] as String?,
    );
  }

  @override
  String toString() {
    return 'FormLifecycleEvent(eventType: $eventType, formId: $formId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FormLifecycleEvent &&
        other.eventType == eventType &&
        other.formId == formId;
  }

  @override
  int get hashCode => eventType.hashCode ^ formId.hashCode;
}
