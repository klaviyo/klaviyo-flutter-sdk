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
        val plugin = KlaviyoFlutterSdkPlugin.instance
        if (plugin == null) {
            Registry.log.info("KlaviyoFlutterSdkPlugin not attached; dropping silent push.")
            return
        }

        Registry.log.info("Silent push received: forwarding to Flutter event stream.")

        // RemoteMessage.data is Map<String, String>, so decode key_value_pairs to match
        // the shape iOS gets free from the APNs payload. Malformed JSON keeps the string.
        val pairs = message.keyValuePairs
        plugin.handleSilentPush(
            pairs?.let { message.data + (Constants.KEY_VALUE_PAIRS to it) } ?: message.data,
        )
    }
}
