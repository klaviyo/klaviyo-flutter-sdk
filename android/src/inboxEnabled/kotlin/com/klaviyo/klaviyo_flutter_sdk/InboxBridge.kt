package com.klaviyo.klaviyo_flutter_sdk

import com.klaviyo.core.MissingKlaviyoModule
import com.klaviyo.inbox.InboxArchiveFilter
import com.klaviyo.inbox.InboxChangeListener
import com.klaviyo.inbox.InboxCursor
import com.klaviyo.inbox.InboxDestination
import com.klaviyo.inbox.InboxException
import com.klaviyo.inbox.InboxMessage
import com.klaviyo.inbox.InboxPage
import com.klaviyo.inbox.InboxQuery
import com.klaviyo.inbox.InboxReadFilter
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
        readFilter: String?,
        archiveFilter: String?,
        onResult: (InboxBridgeResult<Map<String, Any?>>) -> Unit,
    ) {
        val query =
            try {
                InboxQuery(
                    // InboxQuery clamps pageSize to 1..100 itself; pass it
                    // through rather than duplicating the clamp here.
                    pageSize = pageSize,
                    cursor = cursor?.let(::InboxCursor),
                    readFilter = readFilter.toReadFilter(),
                    archiveFilter = archiveFilter.toArchiveFilter(),
                )
            } catch (e: IllegalArgumentException) {
                onResult(InboxBridgeResult.Failure(InboxErrorCodes.STORAGE_FAILURE, e.message))
                return
            }
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
     * Collects the native inbox change signal while Dart is subscribed.
     *
     * `KlaviyoInbox.addChangeListener` collects `MobileInbox.changes` off the
     * main thread and invokes the listener on it, so no store work happens on
     * the main thread here. The listener is held until
     * [unregisterChangeObserver], which the plugin calls when the event channel
     * is cancelled, so it does not outlive the engine.
     *
     * Registering twice replaces the previous listener rather than leaking one.
     *
     * Never throws. The native inbox is a separate module that registers itself
     * at app startup, so it can be compiled in but not yet registered — in a
     * unit test, or if the provider never ran. `KlaviyoInbox.addChangeListener`
     * throws `MissingKlaviyoModule` in that case, which would escape the event
     * channel's `onListen` and break every other event on it. The inbox API
     * itself reports that state as INBOX_UNAVAILABLE instead, so this drops the
     * change signal and leaves the plugin's other streams working.
     */
    fun registerChangeObserver(onChanged: () -> Unit) {
        unregisterChangeObserver()
        val listener = InboxChangeListener { onChanged() }
        changeListener = listener
        try {
            KlaviyoInbox.addChangeListener(listener)
        } catch (e: MissingKlaviyoModule) {
            // No inbox provider in this process: nothing will ever change, and
            // the Dart layer learns that from its first fetch, not from here.
            changeListener = null
        }
    }

    /**
     * Stops collecting the native change signal. Safe to call when none is
     * registered.
     */
    fun unregisterChangeObserver() {
        changeListener?.let(KlaviyoInbox::removeChangeListener)
        changeListener = null
    }

    /**
     * The listener currently registered, if any. Held so it can be removed: the
     * native SDK keeps a reference until it is.
     */
    @Volatile
    private var changeListener: InboxChangeListener? = null

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
     * module reports `InvalidCursor` for a bad cursor — including one issued
     * under different filters — and `StorageFailure` for everything else.
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

    /**
     * The Dart wire value is the lowercased filter name. An absent value keeps
     * the native default rather than being an error.
     */
    private fun String?.toReadFilter(): InboxReadFilter =
        when (this?.lowercase()) {
            null, "all" -> InboxReadFilter.ALL
            "unread" -> InboxReadFilter.UNREAD
            "read" -> InboxReadFilter.READ
            else -> throw IllegalArgumentException("Unknown inbox read filter: $this")
        }

    /** @see toReadFilter */
    private fun String?.toArchiveFilter(): InboxArchiveFilter =
        when (this?.lowercase()) {
            null, "active" -> InboxArchiveFilter.ACTIVE
            "archived" -> InboxArchiveFilter.ARCHIVED
            "all" -> InboxArchiveFilter.ALL
            else -> throw IllegalArgumentException("Unknown inbox archive filter: $this")
        }

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
