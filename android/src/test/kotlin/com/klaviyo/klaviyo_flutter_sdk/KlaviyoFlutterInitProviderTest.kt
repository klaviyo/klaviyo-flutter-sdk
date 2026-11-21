package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.klaviyo.core.PushTapDestination
import com.klaviyo.core.Registry
import com.klaviyo.core.config.Log
import com.klaviyo.core.utils.AdvancedAPI
import com.klaviyo.pushFcm.PushTapDispatcher
import com.klaviyo.pushFcm.PushTapObserver
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@OptIn(AdvancedAPI::class)
@RunWith(RobolectricTestRunner::class)
class KlaviyoFlutterInitProviderTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val observers = mutableListOf<PushTapObserver>()
    private val dispatcher =
        mockk<PushTapDispatcher>(relaxed = true) {
            every { onPushTap(any()) } answers { observers += firstArg<PushTapObserver>() }
        }
    private var previousInstance: KlaviyoFlutterSdkPlugin? = null

    @Before
    fun setUp() {
        previousInstance = KlaviyoFlutterSdkPlugin.instance
        KlaviyoFlutterSdkPlugin.instance = null
    }

    @After
    fun tearDown() {
        Registry.unregister<PushTapDispatcher>()
        KlaviyoFlutterSdkPlugin.clearPendingWebLinkTap(context)
        KlaviyoFlutterSdkPlugin.instance = previousInstance
    }

    private fun createProvider() {
        Registry.register<PushTapDispatcher>(dispatcher)
        Robolectric.setupContentProvider(KlaviyoFlutterInitProvider::class.java)
    }

    private fun tap(destination: PushTapDestination) = observers.forEach { it.onPushTap(Intent(), destination) }

    private fun pendingTap(): String? =
        context
            .getSharedPreferences("com.klaviyo.klaviyo_flutter_sdk", Context.MODE_PRIVATE)
            .getString("pending_web_link_tap", null)

    @Test
    fun `onCreate subscribes one observer to the push tap dispatcher`() {
        createProvider()

        assertEquals(1, observers.size)
    }

    @Test
    fun `an external tap with no engine attached is saved for the next attach`() {
        createProvider()

        tap(PushTapDestination.External("https://example.com"))

        val saved = JSONObject(pendingTap() ?: "{}").optJSONObject("payload")
        assertEquals("push_open_web_url", saved?.optString("type"))
        assertEquals("https://example.com", saved?.optJSONObject("data")?.optString("url"))
    }

    @Test
    fun `deep link and open app taps are left to the activity intent`() {
        createProvider()

        tap(PushTapDestination.DeepLink(Uri.parse("myapp://home")))
        tap(PushTapDestination.OpenApp)

        assertNull(pendingTap())
    }

    @Test
    fun `onCreate logs a warning when the push tap dispatcher is unavailable`() {
        val log = mockk<Log>(relaxed = true)
        mockkObject(Registry)
        every { Registry.log } returns log
        try {
            Robolectric.setupContentProvider(KlaviyoFlutterInitProvider::class.java)

            verify { log.warning(match { it.contains("dispatcher unavailable") }, any()) }
        } finally {
            unmockkObject(Registry)
        }
    }
}
