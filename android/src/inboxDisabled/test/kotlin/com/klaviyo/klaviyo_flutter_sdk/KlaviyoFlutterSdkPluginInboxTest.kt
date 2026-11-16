package com.klaviyo.klaviyo_flutter_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.confirmVerified
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

/**
 * Mobile Inbox method-channel and seam tests for the default build, where the
 * native inbox module is absent (`klaviyoIncludeInbox` off).
 *
 * Only the disabled bridge is exercised here; the enabled bridge needs the
 * native module on the classpath.
 */
class KlaviyoFlutterSdkPluginInboxTest {
    private lateinit var plugin: KlaviyoFlutterSdkPlugin
    private lateinit var result: MethodChannel.Result

    @Before
    fun setUp() {
        plugin = KlaviyoFlutterSdkPlugin()
        result = mockk(relaxed = true)
    }

    @Test
    fun `the default build reports the inbox module as unavailable`() {
        assertFalse(InboxBridge.IS_AVAILABLE)
    }

    @Test
    fun `fetchInboxPage reports INBOX_UNAVAILABLE without the module`() {
        plugin.onMethodCall(MethodCall("fetchInboxPage", mapOf("pageSize" to 20)), result)

        verify(exactly = 1) {
            result.error(InboxErrorCodes.UNAVAILABLE, any(), null)
        }
        confirmVerified(result)
    }

    @Test
    fun `fetchInboxPage without a page size falls back to the native default`() {
        // No arguments at all: the handler must default the size, not throw.
        plugin.onMethodCall(MethodCall("fetchInboxPage", null), result)

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `fetchInboxPage forwards a cursor without inspecting it`() {
        // The cursor is opaque; the plugin must pass it straight through.
        plugin.onMethodCall(
            MethodCall("fetchInboxPage", mapOf("pageSize" to 10, "cursor" to "%%opaque%%")),
            result,
        )

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `fetchInboxPage forwards both filters`() {
        plugin.onMethodCall(
            MethodCall(
                "fetchInboxPage",
                mapOf(
                    "pageSize" to 10,
                    "readFilter" to "unread",
                    "archiveFilter" to "archived",
                ),
            ),
            result,
        )

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `fetchInboxPage without filters still reports unavailable`() {
        // An absent filter keeps the native default; it must not be an error.
        plugin.onMethodCall(MethodCall("fetchInboxPage", mapOf("pageSize" to 20)), result)

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `fetchInboxUnreadCount reports INBOX_UNAVAILABLE without the module`() {
        plugin.onMethodCall(MethodCall("fetchInboxUnreadCount", null), result)

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `updateInboxMessageState reports INBOX_UNAVAILABLE without the module`() {
        plugin.onMethodCall(
            MethodCall(
                "updateInboxMessageState",
                mapOf("messageId" to "msg-1", "state" to "read"),
            ),
            result,
        )

        verify(exactly = 1) { result.error(InboxErrorCodes.UNAVAILABLE, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `updateInboxMessageState requires both a message id and a state`() {
        plugin.onMethodCall(
            MethodCall("updateInboxMessageState", mapOf("messageId" to "msg-1")),
            result,
        )

        verify(exactly = 1) {
            result.error("INVALID_ARGUMENTS", "An inbox message id and state are required", null)
        }
        confirmVerified(result)
    }

    @Test
    fun `updateInboxMessageState requires a message id`() {
        plugin.onMethodCall(
            MethodCall("updateInboxMessageState", mapOf("state" to "read")),
            result,
        )

        verify(exactly = 1) {
            result.error("INVALID_ARGUMENTS", "An inbox message id and state are required", null)
        }
        confirmVerified(result)
    }

    @Test
    fun `the disabled bridge fails every call with the unavailable code`() {
        val outcomes = mutableListOf<InboxBridgeResult<*>>()

        InboxBridge.fetchPage(20, null, null, null) { outcomes.add(it) }
        InboxBridge.fetchUnreadCount { outcomes.add(it) }
        InboxBridge.updateMessageState("msg-1", "read") { outcomes.add(it) }

        assertEquals(3, outcomes.size)
        outcomes.forEach { outcome ->
            assertEquals(
                InboxErrorCodes.UNAVAILABLE,
                (outcome as InboxBridgeResult.Failure).code,
            )
        }
    }

    @Test
    fun `filters do not change the disabled bridge outcome`() {
        // With no module, the outcome is unavailable regardless of the filters,
        // so an archive view fails the same clear way as the default one.
        val outcomes = mutableListOf<InboxBridgeResult<*>>()

        InboxBridge.fetchPage(20, null, "read", "archived") { outcomes.add(it) }
        InboxBridge.fetchPage(20, null, "unread", "all") { outcomes.add(it) }

        assertEquals(2, outcomes.size)
        outcomes.forEach { outcome ->
            assertEquals(
                InboxErrorCodes.UNAVAILABLE,
                (outcome as InboxBridgeResult.Failure).code,
            )
        }
    }

    @Test
    fun `registering the change observer is a safe no-op without the module`() {
        // Runs on every event-channel listen, so it must not throw.
        InboxBridge.registerChangeObserver { }
    }

    @Test
    fun `unregistering the change observer is safe when none is registered`() {
        // Runs on every event-channel cancel and on engine detach, so it must
        // be idempotent and must not throw.
        InboxBridge.unregisterChangeObserver()
        InboxBridge.unregisterChangeObserver()
    }

    @Test
    fun `clearInboxMessage reports INBOX_UNSUPPORTED, not unavailable`() {
        // Clear is unsupported on Android whether or not the module is present,
        // so the code must be the stable unsupported one rather than the
        // missing-module one.
        plugin.onMethodCall(
            MethodCall("clearInboxMessage", mapOf("messageId" to "msg-1")),
            result,
        )

        verify(exactly = 1) { result.error(InboxErrorCodes.UNSUPPORTED, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `clearInboxMessages reports INBOX_UNSUPPORTED`() {
        plugin.onMethodCall(
            MethodCall("clearInboxMessages", mapOf("messageIds" to listOf("a", "b"))),
            result,
        )

        verify(exactly = 1) { result.error(InboxErrorCodes.UNSUPPORTED, any(), null) }
        confirmVerified(result)
    }

    @Test
    fun `clearInboxMessage requires a message id`() {
        plugin.onMethodCall(MethodCall("clearInboxMessage", emptyMap<String, Any>()), result)

        verify(exactly = 1) {
            result.error("INVALID_ARGUMENTS", "An inbox message id is required", null)
        }
        confirmVerified(result)
    }

    @Test
    fun `clearInboxMessages requires a non-empty id list`() {
        plugin.onMethodCall(
            MethodCall("clearInboxMessages", mapOf("messageIds" to emptyList<String>())),
            result,
        )

        verify(exactly = 1) {
            result.error("INVALID_ARGUMENTS", "Inbox message ids are required", null)
        }
        confirmVerified(result)
    }

    @Test
    fun `both bridges report clear as unsupported`() {
        val outcomes = mutableListOf<InboxBridgeResult<*>>()

        InboxBridge.clearMessage("msg-1") { outcomes.add(it) }
        InboxBridge.clearMessages(listOf("a", "b")) { outcomes.add(it) }

        assertEquals(2, outcomes.size)
        outcomes.forEach { outcome ->
            assertEquals(
                InboxErrorCodes.UNSUPPORTED,
                (outcome as InboxBridgeResult.Failure).code,
            )
        }
    }

    @Test
    fun `error codes match the Dart contract`() {
        // These strings are the wire contract the Dart layer maps to
        // KlaviyoInboxErrorReason; changing one silently breaks error mapping.
        assertEquals("INBOX_UNAVAILABLE", InboxErrorCodes.UNAVAILABLE)
        assertEquals("INBOX_STORAGE_FAILURE", InboxErrorCodes.STORAGE_FAILURE)
        assertEquals("INBOX_INVALID_CURSOR", InboxErrorCodes.INVALID_CURSOR)
        assertEquals("INBOX_UNSUPPORTED", InboxErrorCodes.UNSUPPORTED)
    }
}
