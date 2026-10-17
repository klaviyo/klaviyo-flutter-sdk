/// Represents a push-notification action surfaced from the native SDKs when a
/// user taps a push that carries an `open_url` action, or taps an action
/// button on a push notification.
///
/// Use [OpenWebUrl] for a notification-body tap whose configured action opens
/// an external web URL. Use [ActionButtonTapped] for a tap on one of the
/// notification's action buttons — match on [ActionButtonTapped.action] to
/// distinguish `open_app`, `deep_link`, and `open_url` buttons.
///
/// Example usage with exhaustive pattern matching:
/// ```dart
/// import 'package:logging/logging.dart';
///
/// final logger = Logger('MyApp');
///
/// klaviyo.onPushAction.listen((action) {
///   switch (action) {
///     case OpenWebUrl():
///       logger.info('Open web URL: ${action.url}');
///     case ActionButtonTapped():
///       logger.info('Action button ${action.buttonId} (${action.action}): '
///           '${action.url}');
///   }
/// });
/// ```
sealed class KlaviyoPushAction {
  const KlaviyoPushAction();

  /// A string identifier for the action type, suitable for logging.
  String get eventName;

  /// Create the appropriate [KlaviyoPushAction] subtype from a map received
  /// from the platform event channel.
  ///
  /// The expected shapes are:
  /// ```json
  /// // notification-body tap with an open_url action
  /// { "type": "push_open_web_url", "data": { "url": "https://..." } }
  ///
  /// // action button tap (any action type)
  /// {
  ///   "type": "push_action_button_tapped",
  ///   "data": {
  ///     "id": "...",
  ///     "label": "...",
  ///     "action": "open_app" | "deep_link" | "open_url",
  ///     "url": "https://..."   // present for deep_link / open_url
  ///   }
  /// }
  /// ```
  factory KlaviyoPushAction.fromMap(Map<String, dynamic> map) {
    final type = map['type'];

    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError("Missing 'data' field in push action map");
    }

    switch (type) {
      case 'push_open_web_url':
        final url = data['url'] as String?;
        if (url == null || url.isEmpty) {
          throw ArgumentError(
            "Missing required field 'url' in push_open_web_url event",
          );
        }
        return OpenWebUrl(url: url);

      case 'push_action_button_tapped':
        final buttonId = data['id'] as String?;
        if (buttonId == null || buttonId.isEmpty) {
          throw ArgumentError(
            "Missing required field 'id' in push_action_button_tapped event",
          );
        }

        // Label is cosmetic and forwarded verbatim; tolerate its absence
        // (defaulting to empty) rather than dropping the event, mirroring how
        // FormCtaClicked treats buttonLabel. The native layers send it
        // conditionally, so requiring it here would silently drop valid taps.
        final label = (data['label'] as String?) ?? '';

        final action = data['action'] as String?;
        if (action == null || action.isEmpty) {
          throw ArgumentError(
            "Missing required field 'action' in push_action_button_tapped "
            'event',
          );
        }
        if (!_validActions.contains(action)) {
          throw ArgumentError(
            "Unknown action '$action' in push_action_button_tapped event",
          );
        }

        final url = data['url'] as String?;
        // `url` is required for url-bearing actions and absent for open_app.
        if (action != 'open_app' && (url == null || url.isEmpty)) {
          throw ArgumentError(
            "Missing required field 'url' for '$action' action button",
          );
        }

        return ActionButtonTapped(
          buttonId: buttonId,
          label: label,
          action: action,
          url: url,
        );

      default:
        throw ArgumentError('Unknown push action type: $type');
    }
  }

  static const Set<String> _validActions = {
    'open_app',
    'deep_link',
    'open_url',
  };
}

/// Triggered when a user taps a push notification whose configured action
/// opens an external web URL (`open_url`).
class OpenWebUrl extends KlaviyoPushAction {
  /// The external web URL to open.
  final String url;

  const OpenWebUrl({required this.url});

  @override
  String get eventName => 'openWebUrl';

  @override
  String toString() => 'OpenWebUrl(url: $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OpenWebUrl && other.url == url;

  @override
  int get hashCode => Object.hash(runtimeType, url);
}

/// Triggered when a user taps an action button on a push notification.
///
/// [action] is one of `open_app`, `deep_link`, or `open_url`. [url] is present
/// for `deep_link` and `open_url` buttons and null for `open_app`.
class ActionButtonTapped extends KlaviyoPushAction {
  /// The identifier of the tapped action button.
  final String buttonId;

  /// The user-visible label of the tapped action button.
  ///
  /// Defaults to an empty string when the native payload omits it.
  final String label;

  /// The button's action type: `open_app`, `deep_link`, or `open_url`.
  final String action;

  /// The URL associated with the button.
  ///
  /// Present for `deep_link` and `open_url` actions; null for `open_app`.
  final String? url;

  const ActionButtonTapped({
    required this.buttonId,
    required this.label,
    required this.action,
    this.url,
  });

  @override
  String get eventName => 'actionButtonTapped';

  @override
  String toString() => 'ActionButtonTapped(buttonId: $buttonId, '
      'label: $label, action: $action, url: $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionButtonTapped &&
          other.buttonId == buttonId &&
          other.label == label &&
          other.action == action &&
          other.url == url;

  @override
  int get hashCode => Object.hash(runtimeType, buttonId, label, action, url);
}
