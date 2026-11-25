import 'package:meta/meta.dart';

/// The platform that issued a [KlaviyoPushToken].
///
/// This is not an enum: new kinds may be added in a minor release, so a
/// `switch` on it needs a default case.
@immutable
final class KlaviyoPushTokenType {
  const KlaviyoPushTokenType._(this.name);

  /// Creates a token type from its name (`apns` or `fcm`). Unrecognized values
  /// keep their raw value as [name].
  factory KlaviyoPushTokenType.fromName(String name) => switch (name) {
        'apns' => apns,
        'fcm' => fcm,
        _ => KlaviyoPushTokenType._(name),
      };

  /// An APNs device token, delivered on iOS.
  static const apns = KlaviyoPushTokenType._('apns');

  /// An FCM registration token, delivered on Android.
  static const fcm = KlaviyoPushTokenType._('fcm');

  /// A stable identifier, suitable for logging.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is KlaviyoPushTokenType && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'KlaviyoPushTokenType($name)';
}

/// A push token delivered by the platform, emitted on [KlaviyoSDK.onPushToken].
@immutable
final class KlaviyoPushToken {
  /// Creates a push token from the [token] string and the [type] of platform
  /// that issued it.
  const KlaviyoPushToken({required this.token, required this.type});

  /// The token the platform delivered: the APNs device token on iOS, the FCM
  /// registration token on Android.
  final String token;

  /// The platform that issued [token].
  final KlaviyoPushTokenType type;

  @override
  bool operator ==(Object other) =>
      other is KlaviyoPushToken && other.token == token && other.type == type;

  @override
  int get hashCode => Object.hash(token, type);

  @override
  String toString() => 'KlaviyoPushToken(token: $token, type: $type)';
}
