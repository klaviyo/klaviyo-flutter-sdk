package com.klaviyo.klaviyo_flutter_sdk

import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.core.Registry
import com.klaviyo.pushFcm.KlaviyoPushService

/**
 * FCM service that forwards Klaviyo silent pushes (data-only messages, with or
 * without `key_value_pairs`) to the Flutter `EventChannel` as
 * `{type: 'silent_push_received', data: <RemoteMessage.data>}`, mirroring the iOS
 * `handleSilentPush` path.
 *
 * Host apps must declare this service (or a subclass of it) for
 * `com.google.firebase.MESSAGING_EVENT` in their `AndroidManifest.xml` — see the
 * "Silent Push" section of the README. Plugin-side auto-registration is
 * unreliable when the host app also depends on `firebase_messaging`, because
 * `FlutterFirebaseMessagingService` competes for the same intent and FCM's
 * service-resolution gives precedence to host-app declarations over library
 * declarations.
 *
 * Hosts that need custom push handling beyond Klaviyo's defaults should extend
 * this class (not [KlaviyoPushService] directly) so silent push forwarding to
 * Flutter is preserved.
 */
open class KlaviyoFlutterPushService : KlaviyoPushService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Silent Klaviyo pushes WITHOUT `key_value_pairs` only hit this callback —
        // the parent class doesn't route them through onKlaviyoCustomDataMessageReceived.
        // Pushes WITH `key_value_pairs` are handled in that override below to avoid
        // double-firing the silent_push_received event.
        if (isSilentKlaviyoPush(message) && !message.data.containsKey("key_value_pairs")) {
            forwardSilentPush(message)
        }
    }

    override fun onKlaviyoCustomDataMessageReceived(
        customData: Map<String, String>,
        message: RemoteMessage,
    ) {
        super.onKlaviyoCustomDataMessageReceived(customData, message)

        // Standard Klaviyo notifications can also carry key_value_pairs; only forward
        // when there's no notification payload (i.e. a true silent push).
        if (message.notification == null) {
            forwardSilentPush(message)
        }
    }

    private fun isSilentKlaviyoPush(message: RemoteMessage): Boolean = message.notification == null && message.data.containsKey("_k")

    private fun forwardSilentPush(message: RemoteMessage) {
        Registry.log.info("Silent push received: forwarding to Flutter event stream.")

        // Forward the full RemoteMessage.data map so the Dart-side payload contains
        // everything Klaviyo sent (e.g. `_k`, `key_value_pairs`, `notification_tag`),
        // matching the spirit of iOS's full userInfo.
        val plugin = KlaviyoFlutterSdkPlugin.instance
        if (plugin != null) {
            plugin.handleSilentPush(message.data)
            return
        }

        // Plugin not attached — typically because FCM woke the app process to
        // deliver this message while the user had the app killed. Persist so the
        // plugin can replay it on the next engine attach.
        Registry.log.info(
            "KlaviyoFlutterSdkPlugin not attached; persisting silent push for replay.",
        )
        SilentPushCache.persist(applicationContext, message.data)
    }
}
