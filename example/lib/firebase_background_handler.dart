import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Logs Klaviyo push data (silent pushes, and visible pushes with key/value
/// pairs) that firebase_messaging delivers in the background.
///
/// Kept for coverage: registering a firebase_messaging background handler spins
/// up its own FlutterEngine next to the main one and the Klaviyo headless one.
/// It runs for the same push as `klaviyoBackgroundPushDataHandler`.
///
/// Must be top level and `vm:entry-point` annotated. Runs in its own isolate, so the
/// app's `Logger` isn't configured there and `debugPrint` is the only output that
/// reaches logcat. Receives the raw FCM payload, so `key_value_pairs` is a JSON string
/// rather than the decoded map the Klaviyo handler receives.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Klaviyo pushes carry the `_k` tracking parameter. Push data is a silent
  // push (no title or body) or any push with key/value pairs.
  final data = message.data;
  final isSilent = data['title'] == null && data['body'] == null;
  final isKlaviyoPushData = data.containsKey('_k') &&
      (isSilent || data.containsKey('key_value_pairs'));

  if (!isKlaviyoPushData) return;

  debugPrint('Background push data (Firebase): ${data['key_value_pairs']}');
}
