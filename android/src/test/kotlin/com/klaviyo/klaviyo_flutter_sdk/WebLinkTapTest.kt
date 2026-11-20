package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import android.content.Intent
import com.klaviyo.core.Constants
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class WebLinkTapTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    @After
    fun tearDown() {
        KlaviyoFlutterSdkPlugin.clearPendingWebLinkTap(context)
    }

    @Test
    fun `body tap maps to push_open_web_url`() {
        assertEquals(
            mapOf("type" to "push_open_web_url", "data" to mapOf("url" to "https://example.com")),
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(Intent(), "https://example.com"),
        )
    }

    @Test
    fun `open_url button maps to push_action_button_tapped`() {
        val intent =
            Intent()
                .putExtra(Constants.PACKAGE_PREFIX + "Button ID", "b1")
                .putExtra(Constants.PACKAGE_PREFIX + "Button Label", "Shop")

        assertEquals(
            mapOf(
                "type" to "push_action_button_tapped",
                "data" to mapOf("id" to "b1", "action" to "open_url", "url" to "https://example.com/shop", "label" to "Shop"),
            ),
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(intent, "https://example.com/shop"),
        )
    }

    @Test
    fun `an expired saved tap is not restored`() {
        val saved =
            JSONObject()
                .put("time", System.currentTimeMillis() - KlaviyoFlutterSdkPlugin.PENDING_WEB_LINK_TAP_TTL_MS - 1)
                .put("payload", JSONObject(mapOf("type" to "push_open_web_url")))
        prefs().edit().putString(PENDING_KEY, saved.toString()).commit()

        KlaviyoFlutterSdkPlugin.restorePendingWebLinkTap(context)

        assertNull(prefs().getString(PENDING_KEY, null))
        assertNull(cachedPushAction())
    }

    @Test
    fun `an unreadable saved tap is discarded`() {
        prefs().edit().putString(PENDING_KEY, "not json").commit()

        KlaviyoFlutterSdkPlugin.restorePendingWebLinkTap(context)

        assertNull(prefs().getString(PENDING_KEY, null))
        assertNull(cachedPushAction())
    }

    private fun prefs() = context.getSharedPreferences("com.klaviyo.klaviyo_flutter_sdk", Context.MODE_PRIVATE)

    private fun cachedPushAction(): Any? =
        KlaviyoFlutterSdkPlugin::class.java.getDeclaredField("cachedPushAction").run {
            isAccessible = true
            get(null)
        }

    private companion object {
        const val PENDING_KEY = "pending_web_link_tap"
    }
}
