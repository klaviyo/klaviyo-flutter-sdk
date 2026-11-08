import 'dart:convert';

import 'package:meta/meta.dart';

/// The data a Klaviyo push delivers to Dart through [KlaviyoSDK.onPushData].
///
/// Delivered for every silent push, and for every visible push that carries
/// key/value pairs.
@experimental
@immutable
class KlaviyoPushData {
  /// Creates push data from the full push [payload].
  KlaviyoPushData(Map<String, dynamic> payload)
      : payload = Map.unmodifiable(payload);

  /// The full push payload: the APNs `userInfo` on iOS, the FCM data map on
  /// Android. On Android, `_k` and `key_value_pairs` are decoded to maps; other
  /// JSON-valued fields stay strings.
  final Map<String, dynamic> payload;

  /// The key/value pairs set on the push in Klaviyo, or null if it has none.
  ///
  /// Decodes them if they arrive as a JSON string.
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
  String toString() => 'KlaviyoPushData($payload)';
}
