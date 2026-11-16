package com.klaviyo.klaviyo_flutter_sdk

/**
 * Default Mobile Inbox bridge: the native inbox module is not in this build.
 *
 * Compiled instead of `src/inboxEnabled` unless `klaviyoIncludeInbox=true` is
 * set in the host app's `gradle.properties`. Every call reports
 * [InboxErrorCodes.UNAVAILABLE], which the Dart layer surfaces as a typed
 * `KlaviyoInboxException` rather than a confusing null or a missing-method
 * error.
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
        onResult: (InboxBridgeResult<Map<String, Any?>>) -> Unit,
    ) = onResult(unavailable)

    fun fetchUnreadCount(onResult: (InboxBridgeResult<Int>) -> Unit) = onResult(unavailable)

    fun updateMessageState(
        messageId: String,
        state: String,
        onResult: (InboxBridgeResult<Boolean>) -> Unit,
    ) = onResult(unavailable)

    /**
     * No-op: without the inbox module no inbox change can be observed.
     *
     * TODO(MAGE-1102): register the native inbox change listener here once the
     * Android SDK exposes one, and forward each change to
     * `eventSink.success(mapOf("type" to "inbox_changed"))` so Dart's
     * `inboxChanged` stream matches iOS.
     */
    fun registerChangeObserver(
        @Suppress("UNUSED_PARAMETER") onChanged: () -> Unit,
    ) = Unit
}
