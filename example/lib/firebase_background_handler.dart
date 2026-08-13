import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles silent pushes delivered while the app is terminated, which
/// `onPushNotification` cannot reach — the workaround the README recommends.
///
/// Also keep it for coverage: registering a background handler spins up a second
/// FlutterEngine, the case that used to strand silent pushes. Nothing else in this
/// repo exercises it.
///
/// Must be top level and `vm:entry-point` annotated. Runs in its own isolate, so the
/// app's `Logger` isn't configured there and `debugPrint` is the only output that
/// reaches logcat. Receives the raw FCM payload, so `key_value_pairs` is a JSON string
/// rather than the decoded map the plugin's event stream provides. Also fires while
/// merely backgrounded, alongside `onPushNotification` — guard against double handling.
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
