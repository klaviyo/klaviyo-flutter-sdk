package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import com.klaviyo.core.Registry
import org.json.JSONObject

/**
 * Persists a single pending silent push across process boundaries so it can be
 * replayed once the Flutter engine attaches.
 *
 * Used when [KlaviyoFlutterPushService] receives a silent push while
 * [KlaviyoFlutterSdkPlugin] isn't attached (e.g. FCM wakes the app process to
 * deliver a message while the user has the app killed). On the next attach, the
 * plugin reads the persisted entry and emits it to the Flutter event stream.
 *
 * Last-write-wins semantics match iOS's `cachedSilentPush` (single in-memory
 * field). Multiple silent pushes arriving back-to-back while the app is killed
 * collapse to the most recent — an acceptable limitation for an edge case.
 */
internal object SilentPushCache {
    private const val PREFS_NAME = "klaviyo_flutter_sdk"
    private const val KEY_PENDING_SILENT_PUSH = "pending_silent_push"

    fun persist(
        context: Context,
        data: Map<String, String>,
    ) {
        val json = JSONObject(data as Map<*, *>).toString()
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_SILENT_PUSH, json)
            .apply()
    }

    fun consume(context: Context): Map<String, String>? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PENDING_SILENT_PUSH, null) ?: return null
        prefs.edit().remove(KEY_PENDING_SILENT_PUSH).apply()

        return try {
            val obj = JSONObject(json)
            obj
                .keys()
                .asSequence()
                .associateWith { key -> obj.optString(key) }
        } catch (e: Exception) {
            Registry.log.warning("Failed to deserialize cached silent push: ${e.message}")
            null
        }
    }
}
