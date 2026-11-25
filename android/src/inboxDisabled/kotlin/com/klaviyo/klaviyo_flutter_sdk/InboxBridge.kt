package com.klaviyo.klaviyo_flutter_sdk

/**
 * Default Mobile Inbox bridge: the native inbox module is not in this build.
 *
 * Compiled instead of `src/inboxEnabled` unless `klaviyoIncludeInbox=true` is
 * set in the host app's `gradle.properties`. Every call reports
 * [InboxErrorCodes.UNAVAILABLE], which the Dart layer surfaces as a typed
 * `KlaviyoInboxException` rather than a confusing null or a missing-method
 * error.
 *
 * The signatures mirror the enabled bridge exactly, so the plugin code that
 * calls them is identical in both builds.
 */
internal object InboxBridge {
    const val IS_AVAILABLE: Boolean = false

    /** Mirrors the native module's `InboxQuery.DEFAULT_PAGE_SIZE`. */
    const val DEFAULT_PAGE_SIZE: Int = 20

    private val unavailable =
        InboxBridgeResult.Failure(
            InboxErrorCodes.UNAVAILABLE,
            "Mobile Inbox requires the inbox module. " +
                "Add 'klaviyoIncludeInbox=true' to gradle.properties",
        )

    fun fetchPage(
        pageSize: Int,
        cursor: String?,
        readFilter: String?,
        archiveFilter: String?,
        onResult: (InboxBridgeResult<Map<String, Any?>>) -> Unit,
    ) = onResult(unavailable)

    fun fetchUnreadCount(onResult: (InboxBridgeResult<Int>) -> Unit) = onResult(unavailable)

    fun updateMessageState(
        messageId: String,
        state: String,
        onResult: (InboxBridgeResult<Boolean>) -> Unit,
    ) = onResult(unavailable)

    /** @see updateMessageState, which reports the same unavailable result */
    fun trackMessageClick(
        @Suppress("UNUSED_PARAMETER") messageId: String,
        @Suppress("UNUSED_PARAMETER") actionId: String?,
        @Suppress("UNUSED_PARAMETER") properties: Map<*, *>?,
        onResult: (InboxBridgeResult<Boolean>) -> Unit,
    ) = onResult(unavailable)

    /** @see updateMessageState, which reports the same unavailable result */
    fun updateMessageStates(
        @Suppress("UNUSED_PARAMETER") state: String,
        @Suppress("UNUSED_PARAMETER") filter: Map<*, *>?,
        onResult: (InboxBridgeResult<Int>) -> Unit,
    ) = onResult(unavailable)

    /** @see KlaviyoInbox.clearAll */
    fun clearAll(onResult: (InboxBridgeResult<Int>) -> Unit) = onResult(unavailable)

    /**
     * No-op: without the inbox module there is no change signal to collect.
     */
    fun registerChangeObserver(
        @Suppress("UNUSED_PARAMETER") onChanged: () -> Unit,
    ) = Unit

    /** No-op: nothing is ever registered in this build. */
    fun unregisterChangeObserver() = Unit
}
