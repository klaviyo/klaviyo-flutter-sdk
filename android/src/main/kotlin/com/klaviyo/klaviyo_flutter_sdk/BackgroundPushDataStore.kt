package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists what a process with no Flutter engine needs to run the Dart background push data
 * handler: the raw callback handles registered by `KlaviyoSDK.onBackgroundPushData` and the last
 * API key passed to `KlaviyoSDK.initialize`.
 */
internal object BackgroundPushDataStore {
    private const val PREFS_NAME = "com.klaviyo.klaviyo_flutter_sdk.background_push_data"
    private const val KEY_DISPATCHER_HANDLE = "dispatcher_handle"
    private const val KEY_HANDLER_HANDLE = "handler_handle"
    private const val KEY_API_KEY = "api_key"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveHandles(
        context: Context,
        dispatcherHandle: Long,
        handlerHandle: Long,
    ) {
        prefs(context)
            .edit()
            .putLong(KEY_DISPATCHER_HANDLE, dispatcherHandle)
            .putLong(KEY_HANDLER_HANDLE, handlerHandle)
            .apply()
    }

    fun saveApiKey(
        context: Context,
        apiKey: String,
    ) {
        prefs(context).edit().putString(KEY_API_KEY, apiKey).apply()
    }

    fun dispatcherHandle(context: Context): Long = prefs(context).getLong(KEY_DISPATCHER_HANDLE, 0L)

    fun handlerHandle(context: Context): Long = prefs(context).getLong(KEY_HANDLER_HANDLE, 0L)

    fun apiKey(context: Context): String? = prefs(context).getString(KEY_API_KEY, null)

    fun hasHandler(context: Context): Boolean = dispatcherHandle(context) != 0L && handlerHandle(context) != 0L
}
