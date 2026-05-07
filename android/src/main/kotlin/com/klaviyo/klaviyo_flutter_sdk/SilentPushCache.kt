package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import com.klaviyo.core.Registry
import org.json.JSONArray
import org.json.JSONException
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
    private const val PREFS_NAME = "klaviyo_flutter_sdk"
    private const val KEY_PENDING_SILENT_PUSH = "pending_silent_push"

    @Synchronized
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
                } catch (e: JSONException) {
                    Registry.log.warning(
                        "Failed to parse existing cached silent pushes; starting fresh: ${e.message} — payload: $it",
                    )
                    JSONArray()
                }
            } ?: JSONArray()
        array.put(JSONObject(data))
        prefs.edit().putString(KEY_PENDING_SILENT_PUSH, array.toString()).apply()
    }

    @Synchronized
    fun consume(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PENDING_SILENT_PUSH, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING_SILENT_PUSH).apply()

        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                obj.keys().asSequence().associateWith { key: String -> obj.optString(key) }
            }
        } catch (e: JSONException) {
            Registry.log.warning("Failed to deserialize cached silent pushes: ${e.message} — payload: $json")
            emptyList()
        }
    }
}
