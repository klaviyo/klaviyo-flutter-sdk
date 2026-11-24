package com.klaviyo.klaviyo_flutter_sdk

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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

@OptIn(AdvancedAPI::class)
@RunWith(RobolectricTestRunner::class)
class KlaviyoFlutterInitProviderTest {
    private val observers = mutableListOf<PushTapObserver>()
    private val dispatcher =
        mockk<PushTapDispatcher>(relaxed = true) {
            every { onPushTap(any()) } answers { observers += firstArg<PushTapObserver>() }
        }

    @After
    fun tearDown() {
        Registry.unregister<PushTapDispatcher>()
    }

    @Test
    fun `onCreate subscribes one observer to the push tap dispatcher`() {
        Registry.register<PushTapDispatcher>(dispatcher)
        Robolectric.setupContentProvider(KlaviyoFlutterInitProvider::class.java)

        assertEquals(1, observers.size)
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
