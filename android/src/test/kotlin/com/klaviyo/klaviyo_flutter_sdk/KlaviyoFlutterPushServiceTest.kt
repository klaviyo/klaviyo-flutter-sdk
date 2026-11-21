package com.klaviyo.klaviyo_flutter_sdk

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KlaviyoFlutterPushServiceTest {
    private fun isPushData(
        isKlaviyoMessage: Boolean,
        isKlaviyoNotification: Boolean,
        hasKeyValuePairs: Boolean,
    ) = KlaviyoFlutterPushService.isPushData(isKlaviyoMessage, isKlaviyoNotification, hasKeyValuePairs)

    @Test
    fun `silent push without key value pairs is push data`() {
        assertTrue(isPushData(isKlaviyoMessage = true, isKlaviyoNotification = false, hasKeyValuePairs = false))
    }

    @Test
    fun `silent push with key value pairs is push data`() {
        assertTrue(isPushData(isKlaviyoMessage = true, isKlaviyoNotification = false, hasKeyValuePairs = true))
    }

    @Test
    fun `visible push with key value pairs is push data`() {
        assertTrue(isPushData(isKlaviyoMessage = true, isKlaviyoNotification = true, hasKeyValuePairs = true))
    }

    @Test
    fun `visible push without key value pairs is not push data`() {
        assertFalse(isPushData(isKlaviyoMessage = true, isKlaviyoNotification = true, hasKeyValuePairs = false))
    }

    @Test
    fun `non Klaviyo message is never push data`() {
        assertFalse(isPushData(isKlaviyoMessage = false, isKlaviyoNotification = false, hasKeyValuePairs = false))
        assertFalse(isPushData(isKlaviyoMessage = false, isKlaviyoNotification = false, hasKeyValuePairs = true))
        assertFalse(isPushData(isKlaviyoMessage = false, isKlaviyoNotification = true, hasKeyValuePairs = true))
    }
}
