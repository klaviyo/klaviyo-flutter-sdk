package com.klaviyo.klaviyo_flutter_sdk

import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.core.Constants
import com.klaviyo.core.Registry
import com.klaviyo.pushFcm.KlaviyoPushService
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoMessage
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoNotification
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.keyValuePairs

/**
 * FCM service that forwards Klaviyo silent pushes (data-only messages, with or
 * without `key_value_pairs`) to the Flutter `EventChannel` as
 * `{type: 'silent_push_received', data: <RemoteMessage.data>}`, mirroring the iOS
 * `handleSilentPush` path.
 *
 * Auto-registered for `com.google.firebase.MESSAGING_EVENT` via the plugin's
 * `AndroidManifest.xml`; host apps require no manifest changes.
 *
 * Deliberately a superset of the native SDK's `onKlaviyoCustomDataMessageReceived`
 * hook, which only fires when the payload carries `key_value_pairs` and hands back
 * just those pairs: this forwards every Klaviyo silent push along with the full data
 * map, with `key_value_pairs` decoded so Dart sees the same shape it does on iOS.
 * Like the native SDKs, nothing is persisted — a push delivered to a killed
 * process has no Flutter engine to reach and is dropped, not queued for next launch.
 * That gap is known and slated to be addressed; see the README "Parity with the
 * Native SDKs" section.
 */
class KlaviyoFlutterPushService : KlaviyoPushService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // A Klaviyo push is "silent" when it carries the tracking parameter (_k)
        // but has no title/body — i.e. isKlaviyoMessage && !isKlaviyoNotification.
        // This covers silent pushes both with and without `key_value_pairs`.
        if (message.isKlaviyoMessage && !message.isKlaviyoNotification) {
            forwardSilentPush(message)
        }
    }

    private fun forwardSilentPush(message: RemoteMessage) {
        Registry.log.info("Silent push received: forwarding to Flutter event stream.")

        // Plugin not attached means FCM woke the app process while the user had the
        // app killed. Silent pushes are only delivered while the app is running, so
        // drop it rather than persisting it for a later launch.
        KlaviyoFlutterSdkPlugin.instance?.handleSilentPush(buildPayload(message))
            ?: Registry.log.info(
                "KlaviyoFlutterSdkPlugin not attached; dropping silent push.",
            )
    }

    /**
     * `RemoteMessage.data` is a `Map<String, String>`, so `key_value_pairs` arrives as a
     * raw JSON string. iOS hands Dart a decoded map for the same key, straight out of the
     * APNs payload, so parse it here to keep the Dart-side shape identical across platforms.
     * A malformed value leaves the original string in place rather than dropping the entry —
     * the native SDK already logs the parse failure.
     */
    private fun buildPayload(message: RemoteMessage): Map<String, Any?> =
        message.keyValuePairs?.let { pairs ->
            message.data + (Constants.KEY_VALUE_PAIRS to pairs)
        } ?: message.data
}
