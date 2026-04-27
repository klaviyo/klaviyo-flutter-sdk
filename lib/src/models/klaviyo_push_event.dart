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
          iosUserInfo: (map['iosUserInfo'] as Map?)?.cast<String, dynamic>(),
          androidIntentExtras:
              (map['androidIntentExtras'] as Map?)?.cast<String, dynamic>(),
        );
      case 'silent_push_received':
        return SilentPushReceived(
          userInfo: (map['userInfo'] as Map).cast<String, dynamic>(),
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
/// The four typed fields ([title], [body], [url], [imageUrl]) are extracted
/// by the native plugin from the platform's payload, so cross-platform code
/// can handle a tap without dropping into platform-specific maps.
///
/// For access to the full platform payload (e.g. APNs `aps` dict, custom
/// key-value pairs, Klaviyo tracking metadata), use [iosUserInfo] or
/// [androidIntentExtras] — exactly one will be non-null.
final class PushNotificationOpened extends KlaviyoPushEvent {
  /// Notification title, if delivered.
  final String? title;

  /// Notification body, if delivered.
  final String? body;

  /// Deep-link URL associated with the notification, if any.
  final String? url;

  /// URL of the rich-push image, if any.
  final String? imageUrl;

  /// Raw APNs userInfo dictionary as iOS delivers it. **Null on Android.**
  ///
  /// Includes the full nested `aps` structure plus any custom keys
  /// (e.g. `_k`, `url`, `image_url`) at top level. The `_k` value is a
  /// nested dictionary on iOS.
  final Map<String, dynamic>? iosUserInfo;

  /// Raw tap-intent extras as Android delivers them. **Null on iOS.**
  ///
  /// Klaviyo-authored fields use the `com.klaviyo.` prefix
  /// (e.g. `com.klaviyo.title`, `com.klaviyo._k`); system-added extras
  /// may also be present. Values are typically `String`, but `Bundle`
  /// can carry other types so the value side is `dynamic`.
  ///
  /// Note: on Android the `_k` value is a JSON string (e.g.
  /// `'{"Push Platform":"android"}'`), not a parsed map.
  final Map<String, dynamic>? androidIntentExtras;

  const PushNotificationOpened({
    this.title,
    this.body,
    this.url,
    this.imageUrl,
    this.iosUserInfo,
    this.androidIntentExtras,
  });
}

/// Silent (background) push received.
///
/// **iOS only** — Android has no equivalent path in the current SDK.
/// Fires when an APNs payload with `content-available: 1` is received.
final class SilentPushReceived extends KlaviyoPushEvent {
  /// Raw APNs userInfo dictionary.
  final Map<String, dynamic> userInfo;

  const SilentPushReceived({required this.userInfo});
}
