package com.klaviyo.klaviyo_flutter_sdk

import com.klaviyo.inbox.InboxCursor
import com.klaviyo.inbox.InboxDestination
import com.klaviyo.inbox.InboxException
import com.klaviyo.inbox.InboxMessage
import com.klaviyo.inbox.InboxPage
import com.klaviyo.inbox.InboxQuery
import com.klaviyo.inbox.InboxResult
import com.klaviyo.inbox.InboxStateChange
import com.klaviyo.inbox.KlaviyoInbox

/**
 * Opt-in Mobile Inbox bridge onto the native `com.klaviyo:inbox` module.
 *
 * Compiled instead of `src/inboxDisabled` only when `klaviyoIncludeInbox=true`
 * is set in the host app's `gradle.properties`. The native inbox module is not
 * published yet, so that property is off by default and the default build never
 * sees this file.
 *
 * Uses the native module's callback API (`KlaviyoInbox`), which already runs
 * its store work off the main thread and delivers each result on the main
 * thread — so no database work happens on the main thread here, and no
 * coroutine plumbing is needed in the plugin.
 */
internal object InboxBridge {
    const val IS_AVAILABLE: Boolean = true

    /** Mirrors the native module's `InboxQuery.DEFAULT_PAGE_SIZE`. */
    const val DEFAULT_PAGE_SIZE: Int = 20

    /** @see KlaviyoInbox.fetchPage */
    fun fetchPage(
        pageSize: Int,
        cursor: String?,
        onResult: (InboxBridgeResult<Map<String, Any?>>) -> Unit,
    ) {
        val query =
            InboxQuery(
                // InboxQuery clamps pageSize to 1..100 itself; pass it through
                // rather than duplicating the clamp here.
                pageSize = pageSize,
                cursor = cursor?.let(::InboxCursor),
            )
        deliver(onResult, { page -> page.toBridgeMap() }) { done ->
            KlaviyoInbox.fetchPage(query, done)
        }
    }

    /** @see KlaviyoInbox.fetchUnreadCount */
    fun fetchUnreadCount(onResult: (InboxBridgeResult<Int>) -> Unit) =
        deliver(onResult, { it }) { done ->
            KlaviyoInbox.fetchUnreadCount(done)
        }

    /** @see KlaviyoInbox.updateMessageState */
    fun updateMessageState(
        messageId: String,
        state: String,
        onResult: (InboxBridgeResult<Boolean>) -> Unit,
    ) {
        val change =
            try {
                state.toStateChange()
            } catch (e: IllegalArgumentException) {
                onResult(InboxBridgeResult.Failure(InboxErrorCodes.STORAGE_FAILURE, e.message))
                return
            }
        deliver(onResult, { it }) { done ->
            KlaviyoInbox.updateMessageState(messageId, change, done)
        }
    }

    /**
     * No-op until the native module exposes a change signal.
     *
     * TODO(MAGE-1102): the Android SDK has no inbox change/invalidation API
     * yet. When it adds one, subscribe here and invoke [onChanged] on each
     * notification; the plugin forwards that to the event channel as a
     * payload-free `inbox_changed` event, matching iOS's
     * `MobileInbox.changes`. Until then Android's `inboxChanged` stream stays
     * silent and consumers rely on fetch-on-startup and fetch-on-resume.
     */
    fun registerChangeObserver(onChanged: () -> Unit) {
        // Intentionally empty — see the TODO above.
        @Suppress("UNUSED_EXPRESSION")
        onChanged
    }

    /**
     * Bridges the native `InboxResult` shape onto [InboxBridgeResult], mapping
     * each documented native failure onto its Dart-facing code.
     */
    private fun <N, T> deliver(
        onResult: (InboxBridgeResult<T>) -> Unit,
        transform: (N) -> T,
        call: ((InboxResult<N>) -> Unit) -> Unit,
    ) {
        call { result ->
            when (result) {
                is InboxResult.Success -> onResult(InboxBridgeResult.Success(transform(result.value)))
                is InboxResult.Failure ->
                    onResult(
                        InboxBridgeResult.Failure(
                            codeFor(result.exception),
                            result.exception.message,
                        ),
                    )
            }
        }
    }

    /**
     * Maps a native inbox failure onto the Dart-facing error code. The native
     * module reports `InvalidCursor` for a bad cursor and `StorageFailure` for
     * everything else.
     */
    private fun codeFor(error: Throwable): String =
        when (error) {
            is InboxException.InvalidCursor -> InboxErrorCodes.INVALID_CURSOR
            else -> InboxErrorCodes.STORAGE_FAILURE
        }

    private fun InboxPage.toBridgeMap(): Map<String, Any?> =
        mapOf(
            "messages" to messages.map { it.toBridgeMap() },
            // The cursor is opaque: forward the native token verbatim.
            "nextCursor" to nextCursor?.token,
        )

    private fun InboxMessage.toBridgeMap(): Map<String, Any?> =
        mapOf(
            "id" to id,
            "title" to title,
            "body" to body,
            "defaultDestination" to defaultDestination.toBridgeMap(),
            "mediaUrl" to mediaUrl,
            "mediaType" to mediaType,
            "customData" to customData,
            "actions" to
                actions.map { action ->
                    mapOf(
                        "id" to action.id,
                        "label" to action.label,
                        "destination" to action.destination.toBridgeMap(),
                    )
                },
            "sentAt" to sentAt,
            "receivedAt" to receivedAt,
            "collapseId" to collapseId,
            "badge" to badge,
            "isRead" to isRead,
            "isArchived" to isArchived,
            "source" to source.rawValue,
        )

    private fun InboxDestination.toBridgeMap(): Map<String, Any?> =
        mapOf(
            "type" to type.rawValue,
            "url" to url,
        )

    /** The Dart wire value is the lowercased state name. */
    private fun String.toStateChange(): InboxStateChange =
        when (this) {
            "read" -> InboxStateChange.MARK_READ
            "unread" -> InboxStateChange.MARK_UNREAD
            "archived" -> InboxStateChange.ARCHIVE
            "unarchived" -> InboxStateChange.UNARCHIVE
            else -> throw IllegalArgumentException("Unknown inbox message state: $this")
        }
}
