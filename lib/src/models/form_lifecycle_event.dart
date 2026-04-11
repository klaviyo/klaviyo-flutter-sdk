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
  /// The form ID of the form associated with this event.
  final String formId;

  /// The display name of the form associated with this event.
  final String formName;

  const FormLifecycleEvent({required this.formId, required this.formName});

  /// Create the appropriate [FormLifecycleEvent] subtype from a map received
  /// from the platform event channel.
  ///
  /// The expected shape is:
  /// ```json
  /// {
  ///   "type": "form_lifecycle_event",
  ///   "data": {
  ///     "event": "formShown" | "formDismissed" | "formCtaClicked",
  ///     "formId": "...",
  ///     "formName": "...",
  ///     "buttonLabel": "...",   // only for formCtaClicked
  ///     "deepLinkUrl": "..."    // only for formCtaClicked
  ///   }
  /// }
  /// ```
  factory FormLifecycleEvent.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError("Missing 'data' field in lifecycle event map");
    }

    final eventString = data['event'] as String?;
    if (eventString == null || eventString.isEmpty) {
      throw ArgumentError("Missing required field 'event' in lifecycle event");
    }

    final formId = data['formId'] as String?;
    if (formId == null || formId.isEmpty) {
      throw ArgumentError(
        "Missing required field 'formId' in lifecycle event",
      );
    }

    final formName = data['formName'] as String?;
    if (formName == null || formName.isEmpty) {
      throw ArgumentError(
        "Missing required field 'formName' in lifecycle event",
      );
    }

    return switch (eventString) {
      'formShown' => FormShown(formId: formId, formName: formName),
      'formDismissed' => FormDismissed(formId: formId, formName: formName),
      'formCtaClicked' => () {
          final buttonLabel = data['buttonLabel'] as String?;
          if (buttonLabel == null || buttonLabel.isEmpty) {
            throw ArgumentError(
              "Missing required field 'buttonLabel' in formCtaClicked event",
            );
          }
          final deepLinkUrl = data['deepLinkUrl'] as String?;
          if (deepLinkUrl == null || deepLinkUrl.isEmpty) {
            throw ArgumentError(
              "Missing required field 'deepLinkUrl' in formCtaClicked event",
            );
          }
          return FormCtaClicked(
            formId: formId,
            formName: formName,
            buttonLabel: buttonLabel,
            deepLinkUrl: deepLinkUrl,
          );
        }(),
      _ => throw ArgumentError('Unknown event type: $eventString'),
    };
  }

  /// A string identifier for the event type, suitable for logging.
  String get eventName;
}

/// Triggered when a form is shown to the user.
class FormShown extends FormLifecycleEvent {
  const FormShown({required super.formId, required super.formName});

  @override
  String get eventName => 'formShown';

  @override
  String toString() => 'FormShown(formId: $formId, formName: $formName)';

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
  const FormDismissed({required super.formId, required super.formName});

  @override
  String get eventName => 'formDismissed';

  @override
  String toString() => 'FormDismissed(formId: $formId, formName: $formName)';

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
  /// The text label of the CTA button.
  final String buttonLabel;

  /// The deep link URL configured for the CTA.
  ///
  /// Always present because native SDKs only dispatch [FormCtaClicked]
  /// when a deep link URL exists.
  final String deepLinkUrl;

  const FormCtaClicked({
    required super.formId,
    required super.formName,
    required this.buttonLabel,
    required this.deepLinkUrl,
  });

  @override
  String get eventName => 'formCtaClicked';

  @override
  String toString() => 'FormCtaClicked(formId: $formId, formName: $formName, '
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
