package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.klaviyo.core.PushTapDestination
import com.klaviyo.core.PushTapReceiver
import com.klaviyo.core.Registry
import com.klaviyo.core.utils.AdvancedAPI
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
    private lateinit var receiver: PushTapReceiver
    private var previousInstance: KlaviyoFlutterSdkPlugin? = null

    @Before
    fun setUp() {
        previousInstance = KlaviyoFlutterSdkPlugin.instance
        KlaviyoFlutterSdkPlugin.instance = null
        Robolectric.setupContentProvider(KlaviyoFlutterInitProvider::class.java)
        receiver = Registry.get<PushTapReceiver>()
    }

    @After
    fun tearDown() {
        Registry.unregister<PushTapReceiver>()
        KlaviyoFlutterSdkPlugin.clearPendingWebLinkTap(context)
        KlaviyoFlutterSdkPlugin.instance = previousInstance
    }

    private fun pendingTap(): String? =
        context
            .getSharedPreferences("com.klaviyo.klaviyo_flutter_sdk", Context.MODE_PRIVATE)
            .getString("pending_web_link_tap", null)

    @Test
    fun `an external tap with no engine attached is saved for the next attach`() {
        receiver.onPushTap(Intent(), PushTapDestination.External("https://example.com"))

        val saved = JSONObject(pendingTap() ?: "{}").optJSONObject("payload")
        assertEquals("push_open_web_url", saved?.optString("type"))
        assertEquals("https://example.com", saved?.optJSONObject("data")?.optString("url"))
    }

    @Test
    fun `deep link and open app taps are left to the activity intent`() {
        receiver.onPushTap(Intent(), PushTapDestination.DeepLink(Uri.parse("myapp://home")))
        receiver.onPushTap(Intent(), PushTapDestination.OpenApp)

        assertNull(pendingTap())
    }
}
