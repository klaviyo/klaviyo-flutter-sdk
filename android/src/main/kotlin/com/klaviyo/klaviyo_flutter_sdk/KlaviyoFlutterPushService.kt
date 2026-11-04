package com.klaviyo.klaviyo_flutter_sdk

import android.app.ActivityManager
import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.core.Constants
import com.klaviyo.core.Registry
import com.klaviyo.pushFcm.KlaviyoPushService
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoMessage
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoNotification
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.keyValuePairs
import org.json.JSONException
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * FCM service that forwards Klaviyo push data to Dart: every silent push (no
 * title/body) and every visible push that carries `key_value_pairs`. Routed by
 * app state like the iOS `handleSilentPush(userInfo:fetchCompletionHandler:)`
 * path:
 *
 * - Foreground: emitted on the Flutter `EventChannel` as
 *   `{type: 'silent_push_received', data: <RemoteMessage.data>}`, which backs
 *   `KlaviyoSDK.onPushData`.
 * - Background with a live engine: passed to the Dart handler registered with
 *   `KlaviyoSDK.onBackgroundPushData` on that engine.
 * - Otherwise (no engine, e.g. app killed, or an engine that never registered
 *   the handler): passed to the stored handler in a headless engine started by
 *   [BackgroundPushDataExecutor].
 *
 * Background paths block this FCM worker thread until the handler finishes, for
 * at most [BACKGROUND_HANDLER_TIMEOUT_SECONDS].
 *
 * Auto-registered for `com.google.firebase.MESSAGING_EVENT` via the plugin's
 * `AndroidManifest.xml`; host apps require no manifest changes.
 */
class KlaviyoFlutterPushService : KlaviyoPushService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        if (isPushData(
                isKlaviyoMessage = message.isKlaviyoMessage,
                isKlaviyoNotification = message.isKlaviyoNotification,
                hasKeyValuePairs = message.keyValuePairs != null,
            )
        ) {
            forwardPushData(message)
        }
    }

    private fun forwardPushData(message: RemoteMessage) {
        // RemoteMessage.data is Map<String, String>, so JSON object values arrive as raw
        // strings. Decode them so Dart sees the maps iOS gets free from the APNs payload.
        val data =
            buildMap<String, Any?> {
                putAll(message.data)
                message.keyValuePairs?.let { put(Constants.KEY_VALUE_PAIRS, it) }
                decodeJsonObject(message.data[Constants.TRACKING_PARAMETER])?.let {
                    put(Constants.TRACKING_PARAMETER, it)
                }
            }

        val plugin = KlaviyoFlutterSdkPlugin.instance
        when {
            plugin != null && isAppInForeground() -> {
                Registry.log.info("Push data received in foreground: forwarding to Flutter event stream.")
                plugin.handleSilentPush(data)
            }

            plugin != null && plugin.hasBackgroundHandler -> {
                Registry.log.info("Push data received in background: forwarding to Dart handler.")
                awaitBackgroundHandler { onComplete -> plugin.dispatchBackgroundPushData(data, onComplete) }
            }

            BackgroundPushDataStore.hasHandler(this) -> {
                Registry.log.info("Push data received with no engine running the handler: using headless engine.")
                awaitBackgroundHandler { onComplete ->
                    BackgroundPushDataExecutor.dispatch(this, data, onComplete)
                }
            }

            else -> {
                Registry.log.info("No background push data handler registered; dropping push data.")
            }
        }
    }

    private fun awaitBackgroundHandler(dispatch: (onComplete: () -> Unit) -> Unit) {
        val latch = CountDownLatch(1)
        dispatch { latch.countDown() }
        if (!latch.await(BACKGROUND_HANDLER_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            Registry.log.warning(
                "Background push data handler did not finish within $BACKGROUND_HANDLER_TIMEOUT_SECONDS seconds",
            )
        }
    }

    private fun isAppInForeground(): Boolean {
        val state = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(state)
        return state.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            state.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }

    internal companion object {
        private const val BACKGROUND_HANDLER_TIMEOUT_SECONDS = 19L

        /**
         * True for a Klaviyo push that is silent (no title/body), or visible with
         * key/value pairs.
         */
        internal fun isPushData(
            isKlaviyoMessage: Boolean,
            isKlaviyoNotification: Boolean,
            hasKeyValuePairs: Boolean,
        ): Boolean = isKlaviyoMessage && (!isKlaviyoNotification || hasKeyValuePairs)
    }

    /**
     * Reads values with [JSONObject.getString]; Klaviyo sends flat string maps, so the
     * coercion loses nothing. Malformed JSON returns null, leaving the raw string in place.
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
