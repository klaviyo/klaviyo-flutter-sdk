package com.klaviyo.klaviyo_flutter_sdk

import android.content.Intent
import com.klaviyo.core.Constants
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class WebLinkTapTest {
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
}
