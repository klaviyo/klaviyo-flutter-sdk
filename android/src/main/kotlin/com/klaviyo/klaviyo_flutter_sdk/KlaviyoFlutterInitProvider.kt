package com.klaviyo.klaviyo_flutter_sdk

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import com.klaviyo.core.PushTapDestination
import com.klaviyo.core.Registry
import com.klaviyo.core.utils.AdvancedAPI
import com.klaviyo.pushFcm.PushTapDispatcher
import com.klaviyo.pushFcm.PushTapObserver

/**
 * Subscribes the plugin to the native [PushTapDispatcher] at process start, so web-link push taps
 * the native trampoline opens in the browser reach the plugin even when no Flutter engine is
 * running. Other taps launch the host activity, where [KlaviyoFlutterSdkPlugin] reads them from
 * the intent.
 */
internal class KlaviyoFlutterInitProvider : ContentProvider() {
    @OptIn(AdvancedAPI::class)
    override fun onCreate(): Boolean {
        val appContext =
            context?.applicationContext ?: run {
                Registry.log.error(
                    "No application context; Android web-link taps won't reach Dart",
                    IllegalStateException("KlaviyoFlutterInitProvider has no application context"),
                )
                return true
            }
        Registry
            .getOrNull<PushTapDispatcher>()
            ?.onPushTap(webLinkTapObserver(appContext))
            ?: Registry.log.warning("Push tap dispatcher unavailable; Android web-link taps won't reach Dart")
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<String>?,
    ): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<String>?,
    ): Int = 0

    internal companion object {
        @OptIn(AdvancedAPI::class)
        internal fun webLinkTapObserver(context: Context) =
            PushTapObserver { intent, destination ->
                if (destination is PushTapDestination.External) {
                    KlaviyoFlutterSdkPlugin.onWebLinkTap(context, intent, destination.url)
                }
            }
    }
}
