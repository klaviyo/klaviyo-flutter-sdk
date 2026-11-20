package com.klaviyo.klaviyo_flutter_sdk

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import com.klaviyo.core.ExternalPushTapReceiver
import com.klaviyo.core.Registry
import com.klaviyo.core.utils.AdvancedAPI

/**
 * Registers the plugin's [ExternalPushTapReceiver] at process start, so web-link push taps the
 * native trampoline opens in the browser reach the plugin even when no Flutter engine is running.
 */
internal class KlaviyoFlutterInitProvider : ContentProvider() {
    @OptIn(AdvancedAPI::class)
    override fun onCreate(): Boolean {
        val appContext = context?.applicationContext ?: return true
        Registry.register<ExternalPushTapReceiver>(
            ExternalPushTapReceiver { intent, url -> KlaviyoFlutterSdkPlugin.onWebLinkTap(appContext, intent, url) },
        )
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
}
