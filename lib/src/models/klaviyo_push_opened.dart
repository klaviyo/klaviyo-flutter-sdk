import 'dart:convert';

import 'package:meta/meta.dart';

/// What the user tapped to open a push, carried on [KlaviyoPushOpened.tap].
///
/// This is not an enum: new kinds may be added in a minor release, so a
/// `switch` on it needs a default case.
@immutable
final class KlaviyoPushTap {
  const KlaviyoPushTap._(this.name);

  /// The notification body.
  static const notification = KlaviyoPushTap._('notification');

  /// One of the notification's action buttons. See [KlaviyoPushOpened.button].
  static const actionButton = KlaviyoPushTap._('actionButton');

  /// The notification body of a push whose action opens an external web URL.
  /// See [KlaviyoPushOpened.webUrl]. On Android this reaches Dart only while
  /// the app process is running.
  static const webUrl = KlaviyoPushTap._('webUrl');

  /// A stable identifier, suitable for logging.
  final String name;

  @override
  String toString() => 'KlaviyoPushTap.$name';
}

/// The action configured on a push action button.
///
/// This is not an enum: new actions may be added in a minor release, so a
/// `switch` on it needs a default case.
@immutable
final class KlaviyoPushButtonAction {
  const KlaviyoPushButtonAction._(this.name);

  /// Creates the action for the raw value the native SDKs send
  /// (`open_app`, `deep_link` or `open_url`). Unrecognized values keep their
  /// raw value as [name].
  factory KlaviyoPushButtonAction.fromName(String name) => switch (name) {
        'open_app' => openApp,
        'deep_link' => deepLink,
        'open_url' => openUrl,
        _ => KlaviyoPushButtonAction._(name),
      };

  /// Opens the app.
  static const openApp = KlaviyoPushButtonAction._('open_app');

  /// Opens a deep link in the app. See [KlaviyoPushButton.url].
  static const deepLink = KlaviyoPushButtonAction._('deep_link');

  /// Opens an external web URL. See [KlaviyoPushButton.url]. On Android this
  /// reaches Dart only while the app process is running.
  static const openUrl = KlaviyoPushButtonAction._('open_url');

  /// The raw value the native SDKs send.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is KlaviyoPushButtonAction && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'KlaviyoPushButtonAction($name)';
}

/// The action button a user tapped on a push.
@immutable
class KlaviyoPushButton {
  const KlaviyoPushButton({
    required this.id,
    required this.label,
    required this.action,
    this.url,
  });

  /// The button's identifier.
  final String id;

  /// The button's user-visible label, or an empty string if the push omits it.
  final String label;

  /// What the button does.
  final KlaviyoPushButtonAction action;

  /// The deep link or web URL the button opens; null for
  /// [KlaviyoPushButtonAction.openApp].
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is KlaviyoPushButton &&
      other.id == id &&
      other.label == label &&
      other.action == action &&
      other.url == url;

  @override
  int get hashCode => Object.hash(id, label, action, url);

  @override
  String toString() =>
      'KlaviyoPushButton(id: $id, label: $label, action: $action, url: $url)';
}

/// A Klaviyo push the user tapped, emitted on [KlaviyoSDK.onPushOpened].
///
/// Emitted once for every tap: on the notification body, on an action button,
/// or on a push that opens a web URL. [tap] says which, and [button] or
/// [webUrl] carries what was tapped.
@immutable
class KlaviyoPushOpened {
  /// Creates an opened push from the full push [payload].
  KlaviyoPushOpened({
    required Map<String, dynamic> payload,
    this.tap = KlaviyoPushTap.notification,
    this.button,
    this.webUrl,
  }) : payload = Map.unmodifiable(payload);

  /// Creates an opened push from a `push_notification_opened` event on the
  /// `klaviyo_events` channel. The optional `action` field holds the
  /// `push_action_button_tapped` or `push_open_web_url` event for the same tap.
  factory KlaviyoPushOpened.fromMap(Map<String, dynamic> map) {
    final data = map['data'];
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final action = map['action'];
    final actionData = action is Map ? action['data'] : null;
    if (action is! Map || actionData is! Map) {
      return KlaviyoPushOpened(payload: payload);
    }

    switch (action['type']) {
      case 'push_action_button_tapped':
        final id = actionData['id'];
        final buttonAction = actionData['action'];
        if (id is! String || buttonAction is! String) break;
        final label = actionData['label'];
        final url = actionData['url'];
        final button = KlaviyoPushButton(
          id: id,
          label: label is String ? label : '',
          action: KlaviyoPushButtonAction.fromName(buttonAction),
          url: url is String && url.isNotEmpty ? url : null,
        );
        return KlaviyoPushOpened(
          payload: payload,
          tap: KlaviyoPushTap.actionButton,
          button: button,
          webUrl: button.action == KlaviyoPushButtonAction.openUrl
              ? button.url
              : null,
        );
      case 'push_open_web_url':
        final url = actionData['url'];
        if (url is! String || url.isEmpty) break;
        return KlaviyoPushOpened(
          payload: payload,
          tap: KlaviyoPushTap.webUrl,
          webUrl: url,
        );
    }
    return KlaviyoPushOpened(payload: payload);
  }

  /// The full push payload: the APNs `userInfo` on iOS, the Klaviyo intent
  /// extras (without the `com.klaviyo.` prefix) on Android.
  final Map<String, dynamic> payload;

  /// What the user tapped.
  final KlaviyoPushTap tap;

  /// The tapped action button, when [tap] is [KlaviyoPushTap.actionButton].
  final KlaviyoPushButton? button;

  /// The external web URL the tap opens: the push's web URL when [tap] is
  /// [KlaviyoPushTap.webUrl], or the button's URL for a
  /// [KlaviyoPushButtonAction.openUrl] button. Null for every other tap.
  final String? webUrl;

  /// The key/value pairs set on the push in Klaviyo, or null if it has none.
  ///
  /// On Android these arrive as a JSON string and are decoded here.
  Map<String, String>? get keyValuePairs {
    final raw = payload['key_value_pairs'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', '$value'));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', '$value'));
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  String toString() => 'KlaviyoPushOpened(tap: $tap, button: $button, '
      'webUrl: $webUrl, payload: $payload)';
}
