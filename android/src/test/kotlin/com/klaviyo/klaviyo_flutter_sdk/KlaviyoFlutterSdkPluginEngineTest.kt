package com.klaviyo.klaviyo_flutter_sdk

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Looper
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import com.klaviyo.analytics.state.ProfileEventObserver
import com.klaviyo.analytics.state.State
import com.klaviyo.core.Constants
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
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
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

        fun webUrlOpens() = messenger.sent.filter { it["type"] == "push_open_web_url" }

        fun registerForms() =
            plugin.onMethodCall(
                MethodCall("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to 60))),
                mockk<MethodChannel.Result>(relaxed = true),
            )

        fun formEvents() = messenger.sent.filter { it["type"] == "form_lifecycle_event" }

        fun pushTokens() =
            messenger.sent
                .filter { it["type"] == "push_token_received" }
                .map { (it["data"] as Map<*, *>)["token"] }
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
        KlaviyoFlutterSdkPlugin.resetEmittedOpens()
        KlaviyoFlutterSdkPlugin.resetCachedPushToken()
        setAutomaticPushTokenForwarding(null)
        Registry.unregister<State>()
        unmockkAll()
    }

    private fun registerState(): MutableList<ProfileEventObserver> {
        val observers = mutableListOf<ProfileEventObserver>()
        Registry.register<State>(
            mockk<State>(relaxed = true) {
                every { onProfileEvent(any()) } answers { observers += firstArg<ProfileEventObserver>() }
                every { offProfileEvent(any()) } answers { observers -= firstArg<ProfileEventObserver>() }
            },
        )
        return observers
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
    fun `held push events wait for an attached ui engine to listen`() {
        val headless = attach()
        val ui = attach()
        ui.attachActivity(pushOpenIntent(buttonId = "btn-1"))
        ui.plugin.handleSilentPush(mapOf("key" to "value"))
        shadowOf(Looper.getMainLooper()).idle()

        headless.listen()
        assertSame(headless.plugin, KlaviyoFlutterSdkPlugin.instance)
        assertEquals(0, headless.messenger.sent.size)

        ui.listen()
        assertSame(ui.plugin, KlaviyoFlutterSdkPlugin.instance)
        assertEquals(1, ui.pushOpens().size)
        assertEquals(1, ui.pushActions().size)
        assertEquals(1, ui.messenger.sent.count { it["type"] == "silent_push_received" })
    }

    @Test
    fun `a launch tap waits for an attached ui engine when headless already listens`() {
        val headless = attach()
        headless.listen()
        val ui = attach()
        ui.attachActivity(pushOpenIntent())

        assertEquals(0, headless.pushOpens().size)
        ui.listen()
        assertEquals(1, ui.pushOpens().size)
    }

    @Test
    fun `held push events replay to a listening headless engine when no ui is attached`() {
        val headless = attach()
        headless.plugin.handleIntent(pushOpenIntent(buttonId = "btn-1"))
        headless.plugin.handleSilentPush(mapOf("key" to "value"))
        shadowOf(Looper.getMainLooper()).idle()

        headless.listen()

        assertEquals(1, headless.pushOpens().size)
        assertEquals(1, headless.pushActions().size)
        assertEquals(1, headless.messenger.sent.count { it["type"] == "silent_push_received" })
    }

    @Test
    fun `form events registered by a secondary engine reach the primary`() {
        val primary = attach()
        primary.listen()
        val secondary = attach()
        secondary.listen()
        secondary.registerForms()

        emitFormShown()
        assertEquals(1, primary.formEvents().size)
        assertEquals(0, secondary.formEvents().size)

        detach(secondary)
        emitFormShown()
        assertEquals(2, primary.formEvents().size)
    }

    @Test
    fun `held push open and action replay once`() {
        val ui = attach()
        ui.attachActivity(pushOpenIntent(buttonId = "btn-1"))

        ui.listen()

        assertEquals(1, ui.pushOpens().size)
        assertEquals(1, ui.pushActions().size)

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

    @Test
    fun `web-link tap with two engines attached emits once to the primary`() {
        val observers = registerState()
        val primary = attach()
        primary.attachActivity()
        primary.listen()
        val secondary = attach()
        secondary.listen()

        assertEquals(1, observers.size)

        val openedPush =
            Event(EventMetric.CUSTOM("\$opened_push")).apply {
                this[EventKey.CUSTOM("web_url")] = "https://example.com"
            }
        observers.forEach { it(openedPush) }
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, primary.webUrlOpens().size)
        assertEquals(mapOf("url" to "https://example.com"), primary.webUrlOpens().single()["data"])
        assertEquals(0, secondary.webUrlOpens().size)
        assertEquals(1, primary.pushOpens().size)
        assertEquals(primary.webUrlOpens().single(), primary.pushOpens().single()["action"])
        assertEquals(0, secondary.pushOpens().size)
    }

    @Test
    fun `web-link tap before any engine listens is held and delivered once to the primary`() {
        val observers = registerState()
        val engine = attach()
        engine.attachActivity()

        val openedPush =
            Event(EventMetric.CUSTOM("\$opened_push")).apply {
                this[EventKey.CUSTOM("Button ID")] = "b1"
                this[EventKey.CUSTOM("Button Action")] = "Open URL"
                this[EventKey.CUSTOM("Button Link")] = "https://example.com/shop"
                this[EventKey.CUSTOM("_k")] = "{\"tm\":\"replay-1\"}"
            }
        observers.forEach { it(openedPush) }
        observers.forEach { it(openedPush) }
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(0, engine.pushOpens().size)

        engine.listen()

        assertEquals(1, engine.pushOpens().size)
        assertEquals(1, engine.pushActions().size)
        assertEquals("open_url", (engine.pushActions().single()["data"] as Map<*, *>)["action"])
    }

    class SubclassedPushService : KlaviyoFlutterPushService() {
        val seen = mutableListOf<String>()

        override fun onNewToken(newToken: String) {
            seen += newToken
            super.onNewToken(newToken)
        }
    }

    private fun rotateToken(
        token: String,
        service: KlaviyoFlutterPushService =
            Robolectric.buildService(KlaviyoFlutterPushService::class.java).create().get(),
    ) {
        service.onNewToken(token)
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun `token rotation reaches the listening engine and Klaviyo`() {
        registerState()
        val engine = attach()
        engine.listen()

        rotateToken("rotated-1")

        assertEquals(listOf("rotated-1"), engine.pushTokens())
        verify(exactly = 1) { Registry.get<State>().pushToken = "rotated-1" }
    }

    @Test
    fun `token rotation before any engine listens is held and delivered once to the first listener`() {
        rotateToken("stale")
        rotateToken("fresh")
        val engine = attach()
        engine.attachActivity()
        assertEquals(emptyList<Any?>(), engine.pushTokens())

        engine.listen()
        assertEquals(listOf("fresh"), engine.pushTokens())

        val later = attach()
        later.listen()
        engine.cancel()
        engine.listen()
        assertEquals(listOf("fresh"), engine.pushTokens())
        assertEquals(emptyList<Any?>(), later.pushTokens())
    }

    @Test
    fun `token rotation with two engines attached emits once to the primary`() {
        val primary = attach()
        primary.attachActivity()
        primary.listen()
        val secondary = attach()
        secondary.listen()

        rotateToken("rotated-2")

        assertEquals(listOf("rotated-2"), primary.pushTokens())
        assertEquals(emptyList<Any?>(), secondary.pushTokens())
    }

    @Test
    fun `a subclass that overrides onNewToken and calls super still emits and forwards`() {
        registerState()
        val engine = attach()
        engine.listen()
        val service = Robolectric.buildService(SubclassedPushService::class.java).create().get()

        rotateToken("rotated-3", service)

        assertEquals(listOf("rotated-3"), service.seen)
        assertEquals(listOf("rotated-3"), engine.pushTokens())
        verify(exactly = 1) { Registry.get<State>().pushToken = "rotated-3" }
    }

    private fun setAutomaticPushTokenForwarding(enabled: Boolean?) {
        val app = RuntimeEnvironment.getApplication()
        val appInfo = shadowOf(app.packageManager).getInternalMutablePackageInfo(app.packageName).applicationInfo!!
        appInfo.metaData =
            Bundle().apply {
                enabled?.let { putBoolean(Constants.AUTOMATIC_PUSH_TOKEN_FORWARDING, it) }
            }
    }

    @Test
    fun `token rotation reaches Dart but not Klaviyo when automatic forwarding is disabled`() {
        setAutomaticPushTokenForwarding(false)
        registerState()
        val engine = attach()
        engine.listen()

        rotateToken("rotated-4")

        assertEquals(listOf("rotated-4"), engine.pushTokens())
        verify(exactly = 0) { Registry.get<State>().pushToken = any() }
    }
}
