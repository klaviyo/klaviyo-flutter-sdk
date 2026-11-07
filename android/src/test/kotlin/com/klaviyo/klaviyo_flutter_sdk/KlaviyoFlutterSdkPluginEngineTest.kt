package com.klaviyo.klaviyo_flutter_sdk

import android.app.Activity
import android.content.Intent
import android.os.Looper
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.core.Registry
import com.klaviyo.core.utils.AdvancedAPI
import com.klaviyo.forms.FormLifecycleEvent
import com.klaviyo.forms.FormLifecycleHandler
import com.klaviyo.forms.registerForInAppForms
import com.klaviyo.forms.registerFormLifecycleHandler
import com.klaviyo.forms.unregisterFormLifecycleHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMethodCodec
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import java.nio.ByteBuffer
import java.nio.ByteOrder

@RunWith(RobolectricTestRunner::class)
class KlaviyoFlutterSdkPluginEngineTest {
    private class FakeMessenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()
        val sent = mutableListOf<Map<*, *>>()

        override fun send(
            channel: String,
            message: ByteBuffer?,
        ) = send(channel, message, null)

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) {
            if (channel == EVENTS && message != null) {
                message.rewind()
                (StandardMethodCodec.INSTANCE.decodeEnvelope(message) as? Map<*, *>)?.let { sent.add(it) }
            }
        }

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) {
            handlers[channel] = handler
        }

        fun streamCall(method: String) {
            val encoded = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
            val message = ByteBuffer.allocateDirect(encoded.capacity()).order(ByteOrder.nativeOrder())
            encoded.rewind()
            message.put(encoded)
            message.flip()
            handlers.getValue(EVENTS)!!.onMessage(message) {}
        }
    }

    private class Engine {
        val messenger = FakeMessenger()
        val plugin = KlaviyoFlutterSdkPlugin()
        private val binding =
            mockk<FlutterPlugin.FlutterPluginBinding> {
                every { applicationContext } returns RuntimeEnvironment.getApplication()
                every { binaryMessenger } returns messenger
            }

        fun attach() = plugin.onAttachedToEngine(binding)

        fun detach() = plugin.onDetachedFromEngine(binding)

        fun listen() = messenger.streamCall("listen")

        fun cancel() = messenger.streamCall("cancel")

        private var newIntentListener: PluginRegistry.NewIntentListener? = null

        private fun activityBinding(launchIntent: Intent? = null) =
            mockk<ActivityPluginBinding>(relaxed = true) {
                every { activity } returns
                    mockk<Activity>(relaxed = true) {
                        every { intent } returns launchIntent
                    }
                every { addOnNewIntentListener(any()) } answers { newIntentListener = firstArg() }
            }

        fun attachActivity(launchIntent: Intent? = null) = plugin.onAttachedToActivity(activityBinding(launchIntent))

        fun detachActivity() = plugin.onDetachedFromActivity()

        fun detachActivityForConfigChanges() = plugin.onDetachedFromActivityForConfigChanges()

        fun reattachActivityForConfigChanges() = plugin.onReattachedToActivityForConfigChanges(activityBinding())

        fun deliverNewIntent(intent: Intent) = newIntentListener!!.onNewIntent(intent)

        fun pushOpens() = messenger.sent.filter { it["type"] == "push_notification_opened" }

        fun pushActions() = messenger.sent.filter { it["type"] == "push_action_button_tapped" }

        fun registerForms() =
            plugin.onMethodCall(
                MethodCall("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to 60))),
                mockk<MethodChannel.Result>(relaxed = true),
            )

        fun formEvents() = messenger.sent.filter { it["type"] == "form_lifecycle_event" }
    }

    private val attached = mutableListOf<Engine>()
    private var formHandler: FormLifecycleHandler? = null

    @OptIn(AdvancedAPI::class)
    @Before
    fun setUp() {
        mockkObject(Klaviyo)
        every { Klaviyo.handlePush(any()) } returns Klaviyo
        every { Klaviyo.isKlaviyoNotificationIntent(any()) } answers { callOriginal() }
        mockkObject(Registry.lifecycleMonitor)
        every { Registry.lifecycleMonitor.assignCurrentActivity(any()) } returns Unit
        mockkStatic("com.klaviyo.forms.InAppFormsKt")
        every { Klaviyo.registerForInAppForms(any()) } returns Klaviyo
        every { Klaviyo.registerFormLifecycleHandler(any()) } answers {
            formHandler = secondArg()
            Klaviyo
        }
        every { Klaviyo.unregisterFormLifecycleHandler() } answers {
            formHandler = null
            Klaviyo
        }
    }

    @After
    fun tearDown() {
        attached.toList().forEach { detach(it) }
        unmockkAll()
    }

    private fun attach() =
        Engine().also {
            it.attach()
            attached.add(it)
        }

    private fun detach(engine: Engine) {
        engine.detach()
        attached.remove(engine)
    }

    private fun emitFormShown() {
        formHandler?.onFormLifecycleEvent(FormLifecycleEvent.FormShown("form-id", "Form"))
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun `detaching a secondary engine keeps the primary form lifecycle stream`() {
        val primary = attach()
        primary.listen()
        primary.registerForms()

        val secondary = attach()
        detach(secondary)

        assertNotNull(formHandler)
        assertSame(primary.plugin, KlaviyoFlutterSdkPlugin.instance)

        emitFormShown()
        assertEquals(1, primary.formEvents().size)
    }

    @Test
    fun `a later listening engine does not take delivery from the primary`() {
        val primary = attach()
        primary.listen()
        primary.registerForms()

        val secondary = attach()
        secondary.listen()
        assertSame(primary.plugin, KlaviyoFlutterSdkPlugin.instance)

        detach(secondary)

        assertSame(primary.plugin, KlaviyoFlutterSdkPlugin.instance)
        emitFormShown()
        assertEquals(1, primary.formEvents().size)
    }

    @Test
    fun `a listening engine attached to an activity is primary over a headless engine`() {
        val headless = attach()
        headless.listen()
        val ui = attach()
        ui.listen()
        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.attachActivity()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.detachActivity()
        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)
    }

    @Test
    fun `cancelling the primary hands delivery to the next listening engine`() {
        val primary = attach()
        primary.attachActivity()
        primary.listen()
        val headless = attach()
        headless.listen()

        primary.cancel()

        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)
    }

    @Test
    fun `detaching the delivering engine moves instance to a remaining engine`() {
        val first = attach()
        first.listen()
        val second = attach()

        detach(first)

        assertSame(second.plugin, KlaviyoFlutterSdkPlugin.instance)
    }

    @Test
    fun `form events reach the remaining engine after the registering engine detaches`() {
        val primary = attach()
        primary.listen()
        primary.registerForms()
        val secondary = attach()
        secondary.listen()

        detach(primary)

        emitFormShown()
        assertEquals(1, secondary.formEvents().size)
    }

    @Test
    fun `held push open replays to the primary chosen after the open arrives`() {
        val headless = attach()
        val ui = attach()
        ui.attachActivity(pushOpenIntent())

        headless.listen()
        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)
        assertEquals(1, headless.pushOpens().size)
        assertEquals(true, headless.pushOpens().single()["replayed"])

        ui.listen()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)
        assertEquals(0, ui.pushOpens().size)
    }

    @Test
    fun `held push open and action replay once with the replayed marker`() {
        val ui = attach()
        ui.attachActivity(pushOpenIntent(buttonId = "btn-1"))

        ui.listen()

        assertEquals(true, ui.pushOpens().single()["replayed"])
        assertEquals(true, ui.pushActions().single()["replayed"])

        ui.cancel()
        ui.listen()
        assertEquals(1, ui.pushOpens().size)
        assertEquals(1, ui.pushActions().size)
    }

    @Test
    fun `push open while a headless engine listens goes to the ui engine once it is primary`() {
        val headless = attach()
        headless.listen()
        val ui = attach()
        ui.attachActivity()
        ui.listen()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.deliverNewIntent(pushOpenIntent())

        assertEquals(1, ui.pushOpens().size)
        assertNull(ui.pushOpens().single()["replayed"])
        assertEquals(0, headless.pushOpens().size)
    }

    @Test
    fun `configuration change keeps the ui engine primary`() {
        val headless = attach()
        headless.listen()
        val ui = attach()
        ui.attachActivity()
        ui.listen()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.detachActivityForConfigChanges()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.reattachActivityForConfigChanges()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.deliverNewIntent(pushOpenIntent())
        assertEquals(1, ui.pushOpens().size)
        assertEquals(0, headless.pushOpens().size)
    }

    @Test
    fun `reattaching after a configuration change makes a ui engine primary`() {
        val headless = attach()
        headless.listen()
        val ui = attach()
        ui.listen()
        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)

        ui.reattachActivityForConfigChanges()

        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)
    }

    private fun pushOpenIntent(buttonId: String? = null) =
        Intent().apply {
            putExtra("com.klaviyo._k", "tracking")
            putExtra("com.klaviyo.title", "Hello")
            if (buttonId != null) {
                putExtra("com.klaviyo.Button ID", buttonId)
                putExtra("com.klaviyo.Button Action", "Open App")
            }
        }

    @Test
    fun `detaching the last engine tears down the form lifecycle handler`() {
        val primary = attach()
        primary.listen()
        primary.registerForms()
        val secondary = attach()

        detach(secondary)
        assertNotNull(formHandler)

        detach(primary)
        assertNull(formHandler)
        assertNull(KlaviyoFlutterSdkPlugin.instance)
    }

    private companion object {
        const val EVENTS = "klaviyo_events"
    }
}
