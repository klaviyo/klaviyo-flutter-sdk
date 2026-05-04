package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import com.klaviyo.core.Registry
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists pending silent pushes across process boundaries so they can be
 * replayed once the Flutter engine attaches.
 *
 * Used when [KlaviyoFlutterPushService] receives a silent push while
 * [KlaviyoFlutterSdkPlugin] isn't attached (e.g. FCM wakes the app process to
 * deliver a message while the user has the app killed). On the next attach, the
 * plugin reads all persisted entries and emits each one to the Flutter event stream.
 */
internal object SilentPushCache {
    // Companion objects are for classes; these constants are already object-scoped.
    private const val PREFS_NAME = "klaviyo_flutter_sdk"
    private const val KEY_PENDING_SILENT_PUSH = "pending_silent_push"

    // SharedPreferences.edit().apply() is thread-safe per Android docs, so concurrent
    // calls from the FCM background thread and the main thread are safe here.
    fun persist(
        context: Context,
        data: Map<String, String>,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_PENDING_SILENT_PUSH, null)
        val array =
            existing?.let {
                try {
                    JSONArray(it)
                } catch (_: Exception) {
                    JSONArray()
                }
            } ?: JSONArray()
        array.put(JSONObject(data as Map<*, *>))
        prefs.edit().putString(KEY_PENDING_SILENT_PUSH, array.toString()).apply()
    }

    fun consume(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PENDING_SILENT_PUSH, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING_SILENT_PUSH).apply()

        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                obj.keys().asSequence().associateWith { key -> obj.optString(key) }
            }
        } catch (e: Exception) {
            Registry.log.warning("Failed to deserialize cached silent pushes: ${e.message} — payload: $json")
            emptyList()
        }
    }
}
