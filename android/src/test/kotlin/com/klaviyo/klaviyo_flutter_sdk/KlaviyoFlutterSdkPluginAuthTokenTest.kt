package com.klaviyo.klaviyo_flutter_sdk

import android.os.Handler
import android.os.Looper
import com.klaviyo.analytics.AuthTokenProvider
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.core.Registry
import com.klaviyo.core.config.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.net.SocketException
import java.nio.ByteBuffer

class KlaviyoFlutterSdkPluginAuthTokenTest {
    private lateinit var plugin: KlaviyoFlutterSdkPlugin
    private lateinit var result: MethodChannel.Result
    private lateinit var messenger: BinaryMessenger
    private val providers = mutableListOf<AuthTokenProvider>()
    private val emitted = mutableListOf<Any?>()
    private var eventHandler: BinaryMessenger.BinaryMessageHandler? = null

    @Before
    fun setUp() {
        mockkObject(Registry)
        every { Registry.log } returns mockk<Log>(relaxed = true)

        mockkObject(Klaviyo)
        mockkStatic(Klaviyo::class)
        every { Klaviyo.registerAuthTokenProvider(capture(providers)) } returns Klaviyo
        every { Klaviyo.unregisterAuthTokenProvider() } returns Klaviyo

        mockkStatic(Looper::class)
        every { Looper.getMainLooper() } returns mockk()
        mockkConstructor(Handler::class)
        every { anyConstructed<Handler>().post(any()) } answers {
            firstArg<Runnable>().run()
            true
        }

        messenger = mockk(relaxed = true)
        val handler = slot<BinaryMessenger.BinaryMessageHandler>()
        every { messenger.setMessageHandler("klaviyo_events", capture(handler)) } answers {
            eventHandler = handler.captured
        }
        val payload = slot<ByteBuffer>()
        every { messenger.send("klaviyo_events", capture(payload)) } answers {
            payload.captured.rewind()
            emitted += StandardMethodCodec.INSTANCE.decodeEnvelope(payload.captured)
        }

        val binding = mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true)
        every { binding.binaryMessenger } returns messenger

        plugin = KlaviyoFlutterSdkPlugin()
        plugin.onAttachedToEngine(binding)
        result = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        plugin.onDetachedFromEngine(mockk(relaxed = true))
        unmockkAll()
    }

    private fun call(
        method: String,
        arguments: Map<String, Any?>? = null,
    ) = plugin.onMethodCall(MethodCall(method, arguments), result)

    private fun listen() = sendEventChannel("listen")

    private fun cancel() = sendEventChannel("cancel")

    private fun sendEventChannel(method: String) {
        val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
        message.rewind()
        eventHandler!!.onMessage(message, mockk(relaxed = true))
    }

    private fun requestToken(provider: AuthTokenProvider = providers.last()): AuthTokenProvider.Callback {
        val callback = mockk<AuthTokenProvider.Callback>(relaxed = true)
        provider.fetchToken(callback)
        return callback
    }

    @Suppress("UNCHECKED_CAST")
    private fun lastRequestId(): String {
        val event = emitted.last() as Map<String, Any?>
        assertEquals("auth_token_requested", event["type"])
        return (event["data"] as Map<String, Any?>)["id"] as String
    }

    @Test
    fun `a token from Dart completes the matching native request`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()

        call("respondToAuthTokenRequest", mapOf("id" to lastRequestId(), "jwt" to "jwt-1"))

        verify(exactly = 1) { callback.onSuccess("jwt-1") }
        verify(exactly = 0) { callback.onFailure(any()) }
    }

    @Test
    fun `a connectivity error from Dart fails the request with a SocketException`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()
        val failure = slot<Throwable>()
        every { callback.onFailure(capture(failure)) } returns Unit

        call(
            "respondToAuthTokenRequest",
            mapOf("id" to lastRequestId(), "error" to "offline", "isConnectivityError" to true),
        )

        assertTrue(failure.captured is SocketException)
        assertEquals("offline", failure.captured.message)
    }

    @Test
    fun `a plain error from Dart fails the request without marking connectivity`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()
        val failure = slot<Throwable>()
        every { callback.onFailure(capture(failure)) } returns Unit

        call("respondToAuthTokenRequest", mapOf("id" to lastRequestId()))

        assertTrue(failure.captured !is SocketException)
        assertEquals("Auth token provider returned no token", failure.captured.message)
    }

    @Test
    fun `each request id can be answered only once`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()
        val id = lastRequestId()

        call("respondToAuthTokenRequest", mapOf("id" to id, "jwt" to "jwt-1"))
        call("respondToAuthTokenRequest", mapOf("id" to id, "jwt" to "jwt-2"))

        verify(exactly = 1) { callback.onSuccess(any()) }
    }

    @Test
    fun `a new request fails the one still waiting for Dart`() {
        listen()
        call("registerAuthTokenProvider")
        val first = requestToken()
        val second = requestToken()

        call("respondToAuthTokenRequest", mapOf("id" to lastRequestId(), "jwt" to "jwt-2"))

        verify(exactly = 1) { first.onFailure(any()) }
        verify(exactly = 0) { first.onSuccess(any()) }
        verify(exactly = 1) { second.onSuccess("jwt-2") }
    }

    @Test
    fun `a request from a replaced registration is failed, not answered`() {
        listen()
        call("registerAuthTokenProvider")
        val oldProvider = providers.last()
        call("registerAuthTokenProvider")

        val stale = requestToken(oldProvider)
        call("respondToAuthTokenRequest", mapOf("id" to lastRequestId(), "jwt" to "jwt-new"))

        verify(exactly = 0) { stale.onSuccess(any()) }
        verify(exactly = 1) { stale.onFailure(any()) }
    }

    @Test
    fun `unregistering fails requests still waiting for Dart`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()

        call("unregisterAuthTokenProvider")

        verify(exactly = 1) { callback.onFailure(any()) }
        verify { Klaviyo.unregisterAuthTokenProvider() }
    }

    @Test
    fun `a request with no Dart listener fails immediately`() {
        call("registerAuthTokenProvider")

        val callback = requestToken()

        verify(exactly = 1) { callback.onFailure(any()) }
        assertTrue(emitted.isEmpty())
    }

    @Test
    fun `cancelling the event stream tears the provider down`() {
        listen()
        call("registerAuthTokenProvider")
        val callback = requestToken()

        cancel()

        verify(exactly = 1) { callback.onFailure(any()) }
        verify(exactly = 1) { Klaviyo.unregisterAuthTokenProvider() }
    }

    @Test
    fun `a silent push before Flutter listens is replayed once on listen`() {
        plugin.handleSilentPush(mapOf("_k" to "first"))
        plugin.handleSilentPush(mapOf("_k" to "second"))

        listen()
        cancel()
        listen()

        assertEquals(
            listOf(mapOf("type" to "silent_push_received", "data" to mapOf("_k" to "second"))),
            emitted,
        )
    }

    @Test
    fun `a silent push after Flutter listens is delivered directly`() {
        listen()

        plugin.handleSilentPush(mapOf("_k" to "live"))

        assertEquals(
            listOf(mapOf("type" to "silent_push_received", "data" to mapOf("_k" to "live"))),
            emitted,
        )
    }
}
