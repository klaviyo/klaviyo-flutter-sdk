package com.klaviyo.klaviyo_flutter_sdk

import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.core.Constants
import com.klaviyo.core.Registry
import com.klaviyo.pushFcm.KlaviyoPushService
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoMessage
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoNotification
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.keyValuePairs
import org.json.JSONException
import org.json.JSONObject

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

        // RemoteMessage.data is Map<String, String>, so JSON object values arrive as raw
        // strings. iOS gets them decoded free from the APNs payload, so decode here to
        // keep the Dart-side shape identical. Malformed JSON keeps the original string.
        plugin.handleSilentPush(
            buildMap<String, Any?> {
                putAll(message.data)
                message.keyValuePairs?.let { put(Constants.KEY_VALUE_PAIRS, it) }
                decodeJsonObject(message.data[Constants.TRACKING_PARAMETER])?.let {
                    put(Constants.TRACKING_PARAMETER, it)
                }
            },
        )
    }

    /**
     * Values are read with [JSONObject.getString], which coerces non-string primitives —
     * matching how the native SDK parses `key_value_pairs`. Klaviyo sends both `_k` and
     * `key_value_pairs` as flat string maps, so nothing is lost in practice.
     */
    private fun decodeJsonObject(raw: String?): Map<String, String>? =
        raw?.let {
            try {
                val json = JSONObject(it)
                json.keys().asSequence().associateWith { key -> json.getString(key) }
            } catch (e: JSONException) {
                Registry.log.warning("Failed to parse JSON, forwarding it as a string: $it", e)
                null
            }
        }
}
