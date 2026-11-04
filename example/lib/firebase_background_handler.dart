import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Logs Klaviyo silent pushes that firebase_messaging delivers in the
/// background.
///
/// Kept for coverage: registering a firebase_messaging background handler spins
/// up its own FlutterEngine next to the main one and the Klaviyo headless one.
/// It runs for the same push as `klaviyoBackgroundSilentPushHandler`.
///
/// Must be top level and `vm:entry-point` annotated. Runs in its own isolate, so the
/// app's `Logger` isn't configured there and `debugPrint` is the only output that
/// reaches logcat. Receives the raw FCM payload, so `key_value_pairs` is a JSON string
/// rather than the decoded map the Klaviyo handler receives.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Klaviyo pushes carry the `_k` tracking parameter; silent ones have no
  // title or body in the data payload.
  final isKlaviyoSilentPush = message.data.containsKey('_k') &&
      message.data['title'] == null &&
      message.data['body'] == null;

  if (!isKlaviyoSilentPush) return;

  debugPrint('Background silent push: ${message.data['key_value_pairs']}');
}
