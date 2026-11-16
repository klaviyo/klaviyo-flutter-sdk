package com.klaviyo.klaviyo_flutter_sdk

// The Mobile Inbox seam between the Flutter plugin and the native
// `com.klaviyo:inbox` module.
//
// The native inbox module is not published yet, so the implementation of
// `InboxBridge` is chosen at build time by the `klaviyoIncludeInbox` Gradle
// property (default `false`):
//
// - `klaviyoIncludeInbox=true` compiles `src/inboxEnabled`, a full bridge onto
//   `com.klaviyo:inbox`.
// - otherwise `src/inboxDisabled` is compiled, which reports every inbox call
//   as `INBOX_UNAVAILABLE`.
//
// Exactly one of the two source sets is ever on the compile classpath, and both
// declare the same `internal object InboxBridge`, so the plugin code that calls
// it is identical either way and the default build needs no native inbox module
// to compile.

/**
 * The outcome of one inbox call, in the plugin's own terms.
 *
 * Deliberately free of native inbox types so the always-compiled plugin code
 * can handle a result without the inbox module on its classpath.
 */
internal sealed class InboxBridgeResult<out T> {
    class Success<out T>(
        val value: T,
    ) : InboxBridgeResult<T>()

    /**
     * @param code One of [InboxErrorCodes], already mapped from the native
     *  failure
     */
    class Failure(
        val code: String,
        val message: String?,
    ) : InboxBridgeResult<Nothing>()
}

/** Error codes the Dart layer maps onto `KlaviyoInboxException`. */
internal object InboxErrorCodes {
    const val UNAVAILABLE = "INBOX_UNAVAILABLE"
    const val STORAGE_FAILURE = "INBOX_STORAGE_FAILURE"
    const val INVALID_CURSOR = "INBOX_INVALID_CURSOR"

    /**
     * The native inbox does not support this operation yet. Distinct from
     * [UNAVAILABLE], which means the module is missing from the build
     * entirely.
     */
    const val UNSUPPORTED = "INBOX_UNSUPPORTED"
}
