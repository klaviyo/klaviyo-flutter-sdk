package com.klaviyo.klaviyo_flutter_sdk

import android.os.Looper
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.forms.FormLifecycleEvent
import com.klaviyo.forms.FormLifecycleHandler
import com.klaviyo.forms.registerForInAppForms
import com.klaviyo.forms.registerFormLifecycleHandler
import com.klaviyo.forms.unregisterFormLifecycleHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import io.mockk.every
import io.mockk.mockk
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

        fun registerForms() =
            plugin.onMethodCall(
                MethodCall("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to 60))),
                mockk<MethodChannel.Result>(relaxed = true),
            )

        fun formEvents() = messenger.sent.filter { it["type"] == "form_lifecycle_event" }
    }

    private val attached = mutableListOf<Engine>()
    private var formHandler: FormLifecycleHandler? = null

    @Before
    fun setUp() {
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
    fun `detaching a listening secondary engine hands delivery back to the primary`() {
        val primary = attach()
        primary.listen()
        primary.registerForms()

        val secondary = attach()
        secondary.listen()
        assertSame(secondary.plugin, KlaviyoFlutterSdkPlugin.instance)

        detach(secondary)

        assertSame(primary.plugin, KlaviyoFlutterSdkPlugin.instance)
        emitFormShown()
        assertEquals(1, primary.formEvents().size)
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
