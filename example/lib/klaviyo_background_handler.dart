import 'package:flutter/foundation.dart';

/// Handles Klaviyo silent pushes received while the app is in the background
/// or not running. Registered in `main()` with
/// `KlaviyoSDK.onBackgroundSilentPush`.
///
/// Must be top level and `vm:entry-point` annotated. On Android it can run in a
/// headless isolate where the app's `Logger` isn't configured, so it logs with
/// `debugPrint`, which reaches logcat and the Xcode console. It must not show UI.
@pragma('vm:entry-point')
Future<void> klaviyoBackgroundSilentPushHandler(
  Map<String, dynamic> data,
) async {
  debugPrint('Klaviyo background silent push: ${data['key_value_pairs']}');
}
