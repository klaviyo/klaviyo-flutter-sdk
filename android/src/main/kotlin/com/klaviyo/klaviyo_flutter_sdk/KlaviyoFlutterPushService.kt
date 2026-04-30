package com.klaviyo.klaviyo_flutter_sdk

import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.core.Registry
import com.klaviyo.pushFcm.KlaviyoPushService
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoMessage
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoNotification

/**
 * FCM service that forwards Klaviyo silent pushes (data-only messages, with or
 * without `key_value_pairs`) to the Flutter `EventChannel` as
 * `{type: 'silent_push_received', data: <RemoteMessage.data>}`, mirroring the iOS
 * `handleSilentPush` path.
 *
 * Auto-registered for `com.google.firebase.MESSAGING_EVENT` via the plugin's
 * `AndroidManifest.xml`; host apps require no manifest changes.
 */
class KlaviyoFlutterPushService : KlaviyoPushService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // A Klaviyo push is "silent" when it carries the tracking parameter (_k)
        // but has no title/body — i.e. isKlaviyoMessage && !isKlaviyoNotification.
        // This covers silent pushes both with and without `key_value_pairs`.
        if (message.isKlaviyoMessage && !message.isKlaviyoNotification) {
            forwardSilentPush(message)
        }
    }

    private fun forwardSilentPush(message: RemoteMessage) {
        Registry.log.info("Silent push received: forwarding to Flutter event stream.")

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
