/// Represents a lifecycle event of an in-app form, carrying contextual metadata
/// about the form and event-specific data.
///
/// Use [formId] and [formName] to identify the form associated with any event.
/// For CTA-specific data, match on [FormCtaClicked] to access
/// [FormCtaClicked.buttonLabel] and [FormCtaClicked.deepLinkUrl].
///
/// Example usage with exhaustive pattern matching:
/// ```dart
/// klaviyo.onFormLifecycleEvent.listen((event) {
///   switch (event) {
///     case FormShown():
///       print('Form shown: ${event.formId}');
///     case FormDismissed():
///       print('Form dismissed: ${event.formId}');
///     case FormCtaClicked():
///       print('CTA clicked: ${event.buttonLabel}');
///   }
/// });
/// ```
sealed class FormLifecycleEvent {
  /// The form ID of the form associated with this event, or null if unavailable.
  final String? formId;

  /// The display name of the form associated with this event, or null if unavailable.
  final String? formName;

  const FormLifecycleEvent({this.formId, this.formName});

  /// Create the appropriate [FormLifecycleEvent] subtype from a map received
  /// from the platform event channel.
  ///
  /// The expected shape is:
  /// ```json
  /// {
  ///   "type": "form_lifecycle_event",
  ///   "data": {
  ///     "event": "form_shown" | "form_dismissed" | "form_cta_clicked",
  ///     "formId": "...",
  ///     "formName": "...",
  ///     "buttonLabel": "...",   // only for form_cta_clicked
  ///     "deepLinkUrl": "..."    // only for form_cta_clicked
  ///   }
  /// }
  /// ```
  factory FormLifecycleEvent.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? {};
    final eventString = data['event'] as String;
    final formId = data['formId'] as String?;
    final formName = data['formName'] as String?;

    return switch (eventString) {
      'form_shown' => FormShown(formId: formId, formName: formName),
      'form_dismissed' => FormDismissed(formId: formId, formName: formName),
      'form_cta_clicked' => FormCtaClicked(
          formId: formId,
          formName: formName,
          buttonLabel: data['buttonLabel'] as String?,
          deepLinkUrl: data['deepLinkUrl'] as String?,
        ),
      _ => throw ArgumentError('Invalid event type: $eventString'),
    };
  }

  /// A string identifier for the event type, suitable for logging.
  String get eventName;
}

/// Triggered when a form is shown to the user.
class FormShown extends FormLifecycleEvent {
  const FormShown({super.formId, super.formName});

  @override
  String get eventName => 'formShown';

  @override
  String toString() =>
      'FormShown(formId: $formId, formName: $formName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormShown &&
          other.formId == formId &&
          other.formName == formName;

  @override
  int get hashCode => Object.hash(runtimeType, formId, formName);
}

/// Triggered when a form is dismissed (closed) by the user.
class FormDismissed extends FormLifecycleEvent {
  const FormDismissed({super.formId, super.formName});

  @override
  String get eventName => 'formDismissed';

  @override
  String toString() =>
      'FormDismissed(formId: $formId, formName: $formName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormDismissed &&
          other.formId == formId &&
          other.formName == formName;

  @override
  int get hashCode => Object.hash(runtimeType, formId, formName);
}

/// Triggered when a user taps a call-to-action (CTA) button in the form.
class FormCtaClicked extends FormLifecycleEvent {
  /// The text label of the CTA button, or null if unavailable.
  final String? buttonLabel;

  /// The deep link URL configured for the CTA, or null if not configured.
  final String? deepLinkUrl;

  const FormCtaClicked({
    super.formId,
    super.formName,
    this.buttonLabel,
    this.deepLinkUrl,
  });

  @override
  String get eventName => 'formCtaClicked';

  @override
  String toString() =>
      'FormCtaClicked(formId: $formId, formName: $formName, '
      'buttonLabel: $buttonLabel, deepLinkUrl: $deepLinkUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormCtaClicked &&
          other.formId == formId &&
          other.formName == formName &&
          other.buttonLabel == buttonLabel &&
          other.deepLinkUrl == deepLinkUrl;

  @override
  int get hashCode =>
      Object.hash(runtimeType, formId, formName, buttonLabel, deepLinkUrl);
}
