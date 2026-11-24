package com.klaviyo.klaviyo_flutter_sdk

import com.klaviyo.inbox.InboxChangeListener
import com.klaviyo.inbox.KlaviyoInbox
import io.mockk.every
import io.mockk.just
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Tests for the inbox-enabled bridge's change observer, compiled only when
 * `klaviyoIncludeInbox=true` so this file exercises the real implementation
 * rather than the disabled stub.
 *
 * The bridge calls `KlaviyoInbox`'s `@JvmStatic` helpers, so they are mocked
 * statically here. That lets the test assert the register/replace/unregister
 * contract without a device or a registered native module.
 */
class InboxBridgeEnabledTest {
    @Before
    fun setUp() {
        mockkStatic(KlaviyoInbox::class)
    }

    @After
    fun tearDown() {
        unmockkStatic(KlaviyoInbox::class)
        InboxBridge.unregisterChangeObserver()
    }

    @Test
    fun `registering forwards through to the native module`() {
        val added = mutableListOf<InboxChangeListener>()
        every { KlaviyoInbox.addChangeListener(capture(added)) } just runs

        InboxBridge.registerChangeObserver { }

        verify(exactly = 1) { KlaviyoInbox.addChangeListener(any()) }
        assert(added.size == 1)
    }

    @Test
    fun `registering does not throw when the inbox provider is not registered`() {
        // The inbox module registers its provider at app startup, so it can be
        // compiled in but absent at runtime. `addChangeListener` throws then,
        // and an escaping throw would break the whole event channel: the call
        // happens inside the plugin's onListen.
        every { KlaviyoInbox.addChangeListener(any()) } throws
            com.klaviyo.core.MissingKlaviyoModule("inbox")

        InboxBridge.registerChangeObserver { }

        // Nothing to remove either, since registration failed.
        InboxBridge.unregisterChangeObserver()
        verify(exactly = 0) { KlaviyoInbox.removeChangeListener(any()) }
    }

    @Test
    fun `registering twice replaces rather than leaking a listener`() {
        val added = mutableListOf<InboxChangeListener>()
        val removed = mutableListOf<InboxChangeListener>()
        every { KlaviyoInbox.addChangeListener(capture(added)) } just runs
        every { KlaviyoInbox.removeChangeListener(capture(removed)) } just runs

        InboxBridge.registerChangeObserver { }
        InboxBridge.registerChangeObserver { }

        verify(exactly = 2) { KlaviyoInbox.addChangeListener(any()) }
        // The first listener is removed before the second is added, so the
        // native module never holds two.
        verify(exactly = 1) { KlaviyoInbox.removeChangeListener(any()) }
        assert(removed.size == 1)
        assert(added.size == 2)
    }

    @Test
    fun `unregistering removes the listener it registered`() {
        val added = mutableListOf<InboxChangeListener>()
        every { KlaviyoInbox.addChangeListener(capture(added)) } just runs
        every { KlaviyoInbox.removeChangeListener(any()) } just runs

        InboxBridge.registerChangeObserver { }
        InboxBridge.unregisterChangeObserver()

        verify(exactly = 1) { KlaviyoInbox.removeChangeListener(added.single()) }
    }

    @Test
    fun `unregistering twice removes once and does not throw`() {
        every { KlaviyoInbox.addChangeListener(any()) } just runs
        every { KlaviyoInbox.removeChangeListener(any()) } just runs

        InboxBridge.registerChangeObserver { }
        InboxBridge.unregisterChangeObserver()
        InboxBridge.unregisterChangeObserver()

        verify(exactly = 1) { KlaviyoInbox.removeChangeListener(any()) }
    }

    @Test
    fun `unregistering with nothing registered does not call the native module`() {
        every { KlaviyoInbox.removeChangeListener(any()) } just runs

        InboxBridge.unregisterChangeObserver()

        verify(exactly = 0) { KlaviyoInbox.removeChangeListener(any()) }
    }

    @Test
    fun `the registered listener invokes the plugin callback`() {
        val added = mutableListOf<InboxChangeListener>()
        every { KlaviyoInbox.addChangeListener(capture(added)) } just runs

        var changes = 0
        InboxBridge.registerChangeObserver { changes++ }
        added.single().onChange()

        assert(changes == 1)
    }

    @Test
    fun `the enabled build reports the module as available`() {
        assert(InboxBridge.IS_AVAILABLE)
    }
}
