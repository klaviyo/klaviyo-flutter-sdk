package com.klaviyo.klaviyo_flutter_sdk

import android.net.Uri
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class WebLinkTapPayloadTest {
    @Before
    fun setUp() {
        mockkStatic(Uri::class)
        every { Uri.parse(any()) } answers {
            val url = firstArg<String>()
            mockk<Uri> { every { scheme } returns url.substringBefore(':', "") }
        }
    }

    @After
    fun tearDown() {
        unmockkStatic(Uri::class)
    }

    private fun openedPush(vararg props: Pair<String, String>): Event =
        Event(EventMetric.CUSTOM("\$opened_push")).apply {
            props.forEach { (key, value) -> this[EventKey.CUSTOM(key)] = value }
        }

    @Test
    fun `body tap with web_url maps to push_open_web_url`() {
        val payload = KlaviyoFlutterSdkPlugin.webLinkTapPayload(openedPush("web_url" to "https://example.com"))

        assertEquals(
            mapOf("type" to "push_open_web_url", "data" to mapOf("url" to "https://example.com")),
            payload,
        )
    }

    @Test
    fun `open_url action button maps to push_action_button_tapped`() {
        val payload =
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(
                openedPush(
                    "Button ID" to "b1",
                    "Button Label" to "Shop",
                    "Button Action" to "Open URL",
                    "Button Link" to "https://example.com/shop",
                ),
            )

        assertEquals(
            mapOf(
                "type" to "push_action_button_tapped",
                "data" to
                    mapOf(
                        "id" to "b1",
                        "action" to "open_url",
                        "url" to "https://example.com/shop",
                        "label" to "Shop",
                    ),
            ),
            payload,
        )
    }

    @Test
    fun `taps that launch the app are ignored`() {
        assertNull(KlaviyoFlutterSdkPlugin.webLinkTapPayload(openedPush()))
        assertNull(
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(
                openedPush("url" to "myapp://home", "web_url" to "https://example.com"),
            ),
        )
        assertNull(
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(
                openedPush("Button ID" to "b1", "Button Action" to "Deep Link", "Button Link" to "myapp://x"),
            ),
        )
        assertNull(
            KlaviyoFlutterSdkPlugin.webLinkTapPayload(
                openedPush("Button ID" to "b1", "Button Action" to "Open App"),
            ),
        )
    }

    @Test
    fun `web_url with a disallowed scheme is ignored`() {
        assertNull(KlaviyoFlutterSdkPlugin.webLinkTapPayload(openedPush("web_url" to "javascript:alert(1)")))
    }

    @Test
    fun `other metrics are ignored`() {
        val event = Event(EventMetric.CUSTOM("Viewed Product")).apply { this[EventKey.CUSTOM("web_url")] = "https://example.com" }

        assertNull(KlaviyoFlutterSdkPlugin.webLinkTapPayload(event))
    }
}
