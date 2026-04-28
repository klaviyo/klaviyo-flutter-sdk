import 'package:flutter/foundation.dart';

/// A push-notification-related event emitted by [KlaviyoSDK.onPushEvent].
///
/// Use exhaustive pattern matching to handle each variant:
///
/// ```dart
/// klaviyo.onPushEvent.listen((event) {
///   switch (event) {
///     case PushTokenReceived(:final token):
///       // ...
///     case PushTokenError(:final error):
///       // ...
///     case PushNotificationOpened(:final title, :final url):
///       // ...
///     case SilentPushReceived():
///       // ... iOS only
///   }
/// });
/// ```
@immutable
sealed class KlaviyoPushEvent {
  const KlaviyoPushEvent();

  /// Parses an event from the platform-channel envelope emitted by the
  /// native plugin.
  ///
  /// The native side is responsible for normalizing platform-specific
  /// payload conventions (e.g. extracting `aps.alert.title` on iOS) into
  /// the flat fields this factory consumes.
  factory KlaviyoPushEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    switch (type) {
      case 'push_token_received':
        return PushTokenReceived(token: map['token'] as String);
      case 'push_token_error':
        return PushTokenError(
          error: map['error'] as String? ?? 'Unknown error',
        );
      case 'push_notification_opened':
        return PushNotificationOpened(
          title: map['title'] as String?,
          body: map['body'] as String?,
          url: map['url'] as String?,
          imageUrl: map['imageUrl'] as String?,
          keyValuePairs:
              (map['keyValuePairs'] as Map?)?.cast<String, dynamic>(),
          iosUserInfo: (map['iosUserInfo'] as Map?)?.cast<String, dynamic>(),
          androidIntentExtras:
              (map['androidIntentExtras'] as Map?)?.cast<String, dynamic>(),
        );
      case 'silent_push_received':
        return SilentPushReceived(
          userInfo: (map['userInfo'] as Map).cast<String, dynamic>(),
          keyValuePairs:
              (map['keyValuePairs'] as Map?)?.cast<String, dynamic>(),
        );
      default:
        throw ArgumentError('Unknown push event type: $type');
    }
  }
}

/// Token registration succeeded.
///
/// Fires after [KlaviyoSDK.registerForPushNotifications] on Android, and on
/// every successful APNs registration (including app launches) on iOS.
final class PushTokenReceived extends KlaviyoPushEvent {
  /// The push token. APNs hex string on iOS, FCM token on Android.
  final String token;

  const PushTokenReceived({required this.token});
}

/// Token registration failed.
final class PushTokenError extends KlaviyoPushEvent {
  /// Human-readable error description from the platform.
  final String error;

  const PushTokenError({required this.error});
}

/// User tapped a Klaviyo-authored push notification.
///
/// Typed fields ([title], [body], [url], [imageUrl], [keyValuePairs]) are
/// extracted by the native plugin from the platform's payload, so
/// cross-platform code can handle a tap without dropping into
/// platform-specific maps.
///
/// For access to the full platform payload (e.g. APNs `aps` dict, Klaviyo
/// tracking metadata), use [iosUserInfo] or [androidIntentExtras] —
/// exactly one will be non-null.
final class PushNotificationOpened extends KlaviyoPushEvent {
  /// Notification title, if delivered.
  final String? title;

  /// Notification body, if delivered.
  final String? body;

  /// Deep-link URL associated with the notification, if any.
  final String? url;

  /// URL of the rich-push image, if any.
  final String? imageUrl;

  /// Custom key-value pairs configured in the Klaviyo dashboard's
  /// "Key/Value Pairs" section. `null` if the push had no key-value pairs.
  ///
  /// Both platforms namespace these into a single `key_value_pairs` field
  /// in the underlying payload; the native plugin parses Android's
  /// JSON-string form into a Map so callers see the same shape on both.
  final Map<String, dynamic>? keyValuePairs;

  /// Raw APNs userInfo dictionary as iOS delivers it. **Null on Android.**
  ///
  /// Layout (Klaviyo iOS conventions):
  /// - `aps.alert.title`, `aps.alert.body` — standard APNs display fields
  /// - `url` (top-level) — Klaviyo deep-link URL
  /// - `rich-media`, `rich-media-type` (top-level) — image URL + format
  /// - `key_value_pairs` (top-level) — already-parsed dict of customer KV pairs
  /// - `body._k` — Klaviyo tracking metadata (note: nested under `body`,
  ///   not at the top level)
  final Map<String, dynamic>? iosUserInfo;

  /// Raw tap-intent extras as Android delivers them. **Null on iOS.**
  ///
  /// Klaviyo-authored fields use the `com.klaviyo.` prefix
  /// (e.g. `com.klaviyo.title`, `com.klaviyo._k`); system-added extras
  /// may also be present. Values are typically `String`, but `Bundle`
  /// can carry other types so the value side is `dynamic`.
  ///
  /// Note: on Android `com.klaviyo._k` and `com.klaviyo.key_value_pairs`
  /// values are JSON strings (FCM data only carries strings), not parsed
  /// maps. [keyValuePairs] above is the parsed form.
  final Map<String, dynamic>? androidIntentExtras;

  const PushNotificationOpened({
    this.title,
    this.body,
    this.url,
    this.imageUrl,
    this.keyValuePairs,
    this.iosUserInfo,
    this.androidIntentExtras,
  });
}

/// Silent (background) push received.
///
/// **iOS only** — Android has no equivalent path in the current SDK.
/// Fires when an APNs payload with `content-available: 1` is received.
final class SilentPushReceived extends KlaviyoPushEvent {
  /// Custom key-value pairs configured in the Klaviyo dashboard's
  /// "Key/Value Pairs" section. `null` if the push had no key-value pairs.
  ///
  /// Silent pushes are commonly used as a transport for app-specific
  /// metadata, so KV pairs are typically the most useful payload to read.
  final Map<String, dynamic>? keyValuePairs;

  /// Raw APNs userInfo dictionary.
  final Map<String, dynamic> userInfo;

  const SilentPushReceived({required this.userInfo, this.keyValuePairs});
}
