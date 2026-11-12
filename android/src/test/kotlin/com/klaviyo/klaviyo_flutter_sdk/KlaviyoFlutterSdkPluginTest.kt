package com.klaviyo.klaviyo_flutter_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.confirmVerified
import io.mockk.mockk
import io.mockk.verify
import org.junit.Before
import org.junit.Test

class KlaviyoFlutterSdkPluginTest {
    private lateinit var plugin: KlaviyoFlutterSdkPlugin
    private lateinit var result: MethodChannel.Result

    @Before
    fun setUp() {
        plugin = KlaviyoFlutterSdkPlugin()
        result = mockk(relaxed = true)
    }

    @Test
    fun `unknown method reports not implemented`() {
        plugin.onMethodCall(MethodCall("notARealMethod", null), result)

        verify(exactly = 1) { result.notImplemented() }
        confirmVerified(result)
    }

    @Test
    fun `handleUniversalTrackingLink without url returns INVALID_URL error`() {
        plugin.onMethodCall(MethodCall("handleUniversalTrackingLink", emptyMap<String, Any>()), result)

        verify(exactly = 1) { result.error("INVALID_URL", "URL cannot be null", null) }
        confirmVerified(result)
    }
}
