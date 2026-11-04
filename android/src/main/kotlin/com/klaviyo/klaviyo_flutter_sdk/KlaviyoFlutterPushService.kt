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
 * FCM service that forwards Klaviyo silent pushes (data-only messages, with or
 * without `key_value_pairs`) to Dart, routed by app state like the iOS
 * `handleSilentPush(userInfo:fetchCompletionHandler:)` path:
 *
 * - Foreground: emitted on the Flutter `EventChannel` as
 *   `{type: 'silent_push_received', data: <RemoteMessage.data>}`.
 * - Background with a live engine: passed to the Dart handler registered with
 *   `KlaviyoSDK.onBackgroundSilentPush` on that engine.
 * - No engine (app killed): passed to that handler in a headless engine started
 *   by [BackgroundSilentPushExecutor].
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

        // A Klaviyo push is "silent" when it carries the tracking parameter (_k)
        // but has no title/body — i.e. isKlaviyoMessage && !isKlaviyoNotification.
        // This covers silent pushes both with and without `key_value_pairs`.
        if (message.isKlaviyoMessage && !message.isKlaviyoNotification) {
            forwardSilentPush(message)
        }
    }

    private fun forwardSilentPush(message: RemoteMessage) {
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
                Registry.log.info("Silent push received in foreground: forwarding to Flutter event stream.")
                plugin.handleSilentPush(data)
            }

            plugin != null -> {
                if (!plugin.hasBackgroundHandler) {
                    Registry.log.info("No background silent push handler registered; dropping silent push.")
                    return
                }
                Registry.log.info("Silent push received in background: forwarding to Dart handler.")
                awaitBackgroundHandler { onComplete -> plugin.dispatchBackgroundSilentPush(data, onComplete) }
            }

            BackgroundSilentPushStore.hasHandler(this) -> {
                Registry.log.info("Silent push received with no Flutter engine: starting headless engine.")
                awaitBackgroundHandler { onComplete ->
                    BackgroundSilentPushExecutor.dispatch(this, data, onComplete)
                }
            }

            else -> {
                Registry.log.info("No Flutter engine or background handler; dropping silent push.")
            }
        }
    }

    private fun awaitBackgroundHandler(dispatch: (onComplete: () -> Unit) -> Unit) {
        val latch = CountDownLatch(1)
        dispatch { latch.countDown() }
        if (!latch.await(BACKGROUND_HANDLER_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            Registry.log.warning(
                "Background silent push handler did not finish within $BACKGROUND_HANDLER_TIMEOUT_SECONDS seconds",
            )
        }
    }

    private fun isAppInForeground(): Boolean {
        val state = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(state)
        return state.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            state.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }

    private companion object {
        const val BACKGROUND_HANDLER_TIMEOUT_SECONDS = 19L
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
