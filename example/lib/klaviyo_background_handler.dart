import 'package:flutter/foundation.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

/// Handles Klaviyo push data (silent pushes, and visible pushes with key/value
/// pairs) received while the app is in the background or not running.
/// Registered in `main()` with `KlaviyoSDK.onBackgroundPushData`.
///
/// Must be top level and `vm:entry-point` annotated. On Android it can run in a
/// headless isolate where the app's `Logger` isn't configured, so it logs with
/// `debugPrint`, which reaches logcat and the Xcode console. It must not show UI.
@pragma('vm:entry-point')
Future<void> klaviyoBackgroundPushDataHandler(KlaviyoPushData data) async {
  debugPrint('Klaviyo background push data: ${data.keyValuePairs}');
}
