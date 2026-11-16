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

    /**
     * Clearing is unsupported on Android whether or not the module is present,
     * so this build reports the same INBOX_UNSUPPORTED result the enabled build
     * does rather than INBOX_UNAVAILABLE.
     *
     * TODO(MAGE-1102 follow-up): switch to INBOX_UNAVAILABLE for a missing
     * module once Android ships a native clear and the enabled build forwards
     * to it.
     */
    fun clearMessage(
        messageId: String,
        onResult: (InboxBridgeResult<Boolean>) -> Unit,
    ) = onResult(clearUnsupported())

    /** @see clearMessage */
    fun clearMessages(
        messageIds: List<String>,
        onResult: (InboxBridgeResult<Int>) -> Unit,
    ) = onResult(clearUnsupported())

    private fun clearUnsupported() =
        InboxBridgeResult.Failure(
            InboxErrorCodes.UNSUPPORTED,
            "Clearing inbox messages is not available on Android yet",
        )

    /**
     * No-op: without the inbox module there is no change signal to collect.
     */
    fun registerChangeObserver(
        @Suppress("UNUSED_PARAMETER") onChanged: () -> Unit,
    ) = Unit

    /** No-op: nothing is ever registered in this build. */
    fun unregisterChangeObserver() = Unit
}
