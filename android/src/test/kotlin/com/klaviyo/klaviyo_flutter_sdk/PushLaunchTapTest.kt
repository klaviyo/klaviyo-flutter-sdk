package com.klaviyo.klaviyo_flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.Klaviyo.isKlaviyoNotificationIntent
import com.klaviyo.core.Registry
import com.klaviyo.core.config.hasManifestKey
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class PushLaunchTapTest {
    private lateinit var plugin: KlaviyoFlutterSdkPlugin
    private val sent = mutableListOf<Any?>()
    private val sink =
        mockk<EventChannel.EventSink>(relaxed = true).also {
            every { it.success(any()) } answers { sent.add(firstArg()) }
        }

    @Before
    fun setUp() {
        mockkObject(Registry)
        every { Registry.log } returns mockk(relaxed = true)
        every { Registry.lifecycleMonitor } returns mockk(relaxed = true)
        mockkObject(Klaviyo)
        mockkStatic(Klaviyo::class)
        every { Klaviyo.handlePush(any()) } returns Klaviyo
        every { Klaviyo.resetProfile() } returns Klaviyo
        every { with(Klaviyo) { any<Intent>().isKlaviyoNotificationIntent } } returns true
        mockkStatic("com.klaviyo.core.config.KlaviyoConfigKt")
        every { any<Context>().hasManifestKey(any()) } returns false

        plugin = KlaviyoFlutterSdkPlugin()
        val engineBinding =
            mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true) {
                every { applicationContext } returns mockk(relaxed = true)
            }
        plugin.onAttachedToEngine(engineBinding)
    }

    @After
    fun tearDown() {
        KlaviyoFlutterSdkPlugin.instance = null
        unmockkAll()
    }

    private fun tapIntent(
        id: String,
        buttonId: String? = null,
        flags: Int = 0,
    ): Intent {
        val extras = mutableMapOf<String, Any?>("com.klaviyo.id" to id)
        if (buttonId != null) {
            extras["com.klaviyo.Button ID"] = buttonId
            extras["com.klaviyo.Button Action"] = "Open App"
            extras["com.klaviyo.Button Label"] = "Shop"
        }
        val bundle =
            mockk<Bundle>().also { bundle ->
                every { bundle.keySet() } returns extras.keys
                every { bundle.get(any()) } answers { extras[firstArg()] }
            }
        return mockk<Intent>(relaxed = true).also { intent ->
            every { intent.extras } returns bundle
            every { intent.flags } returns flags
        }
    }

    private fun launchActivityWith(intent: Intent): ActivityPluginBinding {
        val activity = mockk<Activity> { every { this@mockk.intent } returns intent }
        val binding = mockk<ActivityPluginBinding>(relaxed = true) { every { this@mockk.activity } returns activity }
        plugin.onAttachedToActivity(binding)
        return binding
    }

    private fun getInitialPushNotification(): Any? {
        val captured = slot<Any?>()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        every { result.success(captureNullable(captured)) } returns Unit
        plugin.onMethodCall(MethodCall("getInitialPushNotification", null), result)
        return captured.captured
    }

    private fun openedId(event: Any?): Any? = ((event as Map<*, *>)["data"] as Map<*, *>)["id"]

    @Test
    fun `cold-start tap is flushed to the first listener once and stays readable`() {
        launchActivityWith(tapIntent("launch"))

        plugin.attachEventSink(sink)
        plugin.attachEventSink(sink)

        assertEquals(1, sent.size)
        assertEquals("push_notification_opened", (sent.single() as Map<*, *>)["type"])
        assertEquals("launch", openedId(getInitialPushNotification()))
        assertEquals("launch", openedId(getInitialPushNotification()))
    }

    @Test
    fun `cold-start action button tap is flushed after the open`() {
        launchActivityWith(tapIntent("launch", buttonId = "btn1"))

        plugin.attachEventSink(sink)

        assertEquals(listOf("push_notification_opened", "push_action_button_tapped"), sent.map { (it as Map<*, *>)["type"] })
    }

    @Test
    fun `relaunch from history is tracked natively but not emitted or recorded`() {
        val intent = tapIntent("stale", flags = Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        launchActivityWith(intent)

        plugin.attachEventSink(sink)

        verify(exactly = 1) { Klaviyo.handlePush(intent) }
        assertEquals(emptyList<Any?>(), sent)
        assertNull(getInitialPushNotification())
    }

    @Test
    fun `warm tap is delivered but never recorded as the launch tap`() {
        launchActivityWith(mockk<Intent>(relaxed = true).also { every { it.extras } returns null })
        plugin.attachEventSink(sink)

        plugin.handleIntent(tapIntent("warm"))

        assertEquals("warm", openedId(sent.single()))
        assertNull(getInitialPushNotification())
    }

    @Test
    fun `a later activity attach does not replace the launch tap`() {
        launchActivityWith(tapIntent("launch"))
        launchActivityWith(tapIntent("recreated"))

        assertEquals("launch", openedId(getInitialPushNotification()))
    }

    @Test
    fun `a new tap clears the cached action from an earlier tap`() {
        plugin.handleIntent(tapIntent("first", buttonId = "btn1"))
        plugin.handleIntent(tapIntent("second"))

        plugin.attachEventSink(sink)

        assertEquals(listOf("second"), sent.map { openedId(it) })
    }

    @Test
    fun `resetProfile clears the launch tap`() {
        launchActivityWith(tapIntent("launch"))

        plugin.onMethodCall(MethodCall("resetProfile", null), mockk(relaxed = true))

        assertNull(getInitialPushNotification())
    }
}
