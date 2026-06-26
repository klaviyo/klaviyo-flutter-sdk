package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import com.klaviyo.core.Registry
import org.json.JSONException
import org.json.JSONObject

/**
 * Persists the push-opened payload that launched the app from a terminated
 * state across process boundaries, so it can be replayed once the Flutter
 * engine attaches.
 *
 * Mirrors [SilentPushCache] (which handles cold-start silent pushes) but is
 * single-slot rather than a queue: only one notification tap can cold-launch
 * the app, so only the most recent open is relevant. See
 * klaviyo/klaviyo-flutter-sdk#86.
 *
 * The Dart side reads this cache through `getInitialNotification()` (one-shot
 * pull) or via the `onPushNotification` stream's `onListen` flush — whichever
 * runs first drains the cache (both in-memory and persisted), guaranteeing no
 * double-delivery.
 */
internal object PushOpenedCache {
    private const val PREFS_NAME = "klaviyo_flutter_sdk"
    private const val KEY_PENDING_PUSH_OPENED = "pending_push_opened"

    @Synchronized
    fun persist(
        context: Context,
        data: Map<String, Any?>,
    ) {
        val json =
            try {
                JSONObject().apply {
                    data.forEach { (key, value) -> putTyped(key, value) }
                }
            } catch (e: JSONException) {
                Registry.log.warning(
                    "Failed to serialize cached push-opened payload: ${e.message} — payload: $data",
                )
                return
            }

        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_PUSH_OPENED, json.toString())
            .apply()
    }

    @Synchronized
    fun consume(context: Context): Map<String, Any?>? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PENDING_PUSH_OPENED, null) ?: return null
        prefs.edit().remove(KEY_PENDING_PUSH_OPENED).apply()

        return try {
            val obj = JSONObject(json)
            obj.keys().asSequence().associateWith { key ->
                when (val v = obj.get(key)) {
                    is JSONObject.NULL -> null
                    else -> v
                }
            }
        } catch (e: JSONException) {
            Registry.log.warning(
                "Failed to deserialize cached push-opened payload: ${e.message} — payload: $json",
            )
            null
        }
    }

    @Throws(JSONException::class)
    private fun JSONObject.putTyped(
        key: String,
        value: Any?,
    ) {
        when (value) {
            null -> put(key, JSONObject.NULL)
            is String -> put(key, value)
            is Int -> put(key, value)
            is Long -> put(key, value)
            is Double -> put(key, value)
            is Boolean -> put(key, value)
            else -> put(key, value.toString())
        }
    }
}