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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class WebLinkOpenedPayloadTest {
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
        KlaviyoFlutterSdkPlugin.resetEmittedOpens()
    }

    private fun openedPush(vararg props: Pair<String, String>): Event =
        Event(EventMetric.CUSTOM("\$opened_push")).apply {
            props.forEach { (key, value) -> this[EventKey.CUSTOM(key)] = value }
        }

    @Test
    fun `body web_url tap maps to an open carrying the web URL action`() {
        val payload =
            KlaviyoFlutterSdkPlugin.webLinkOpenedPayload(
                openedPush(
                    "web_url" to "https://example.com",
                    "_k" to "tm-body",
                    "title" to "Sale",
                    "Device ID" to "device",
                    "Push Token" to "token",
                    "_time" to "now",
                    "\$event_id" to "id",
                ),
            )

        assertEquals(
            mapOf(
                "type" to "push_notification_opened",
                "data" to mapOf("web_url" to "https://example.com", "_k" to "tm-body", "title" to "Sale"),
                "action" to mapOf("type" to "push_open_web_url", "data" to mapOf("url" to "https://example.com")),
            ),
            payload,
        )
    }

    @Test
    fun `open_url button tap maps to an open carrying the button action`() {
        val payload =
            KlaviyoFlutterSdkPlugin.webLinkOpenedPayload(
                openedPush(
                    "Button ID" to "b1",
                    "Button Label" to "Open Site",
                    "Button Action" to "Open URL",
                    "Button Link" to "https://example.com/shop",
                ),
            )

        assertEquals("push_notification_opened", payload?.get("type"))
        assertEquals(
            mapOf(
                "type" to "push_action_button_tapped",
                "data" to
                    mapOf(
                        "id" to "b1",
                        "action" to "open_url",
                        "url" to "https://example.com/shop",
                        "label" to "Open Site",
                    ),
            ),
            payload?.get("action"),
        )
    }

    @Test
    fun `taps that launch the app produce no web-link open`() {
        assertNull(KlaviyoFlutterSdkPlugin.webLinkOpenedPayload(openedPush("_k" to "tm")))
        assertNull(
            KlaviyoFlutterSdkPlugin.webLinkOpenedPayload(
                openedPush("Button ID" to "b1", "Button Action" to "Open App"),
            ),
        )
    }

    @Test
    fun `an open for the same delivery is emitted once across both paths`() {
        assertTrue(KlaviyoFlutterSdkPlugin.markOpenEmitted(mapOf("_k" to "tm-2")))
        assertFalse(KlaviyoFlutterSdkPlugin.markOpenEmitted(mapOf("_k" to "tm-2")))
        assertTrue(KlaviyoFlutterSdkPlugin.markOpenEmitted(mapOf("_k" to "tm-3")))
    }

    @Test
    fun `opens without a tracking payload are never deduplicated`() {
        assertTrue(KlaviyoFlutterSdkPlugin.markOpenEmitted(emptyMap()))
        assertTrue(KlaviyoFlutterSdkPlugin.markOpenEmitted(emptyMap()))
    }
}
