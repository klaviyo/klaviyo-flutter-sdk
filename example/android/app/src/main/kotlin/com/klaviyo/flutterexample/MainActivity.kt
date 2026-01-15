package com.klaviyo.flutterexample

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.klaviyo.analytics.Klaviyo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private const val CHANNEL = "klaviyo_sdk"
    private const val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle notification intent on cold start
        intent?.let { handleNotificationIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        // Handle notification intent on warm start
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent) {
        try {
            // Let Klaviyo SDK track the push open
            Klaviyo.handlePush(intent)

            // Extract notification data
            val extras = intent.extras
            if (extras != null && extras.containsKey("_k")) {
                // This is a Klaviyo notification
                val notificationData = mutableMapOf<String, Any?>()

                for (key in extras.keySet()) {
                    val value = extras.get(key)
                    notificationData[key] =
                        when (value) {
                            is String -> value
                            is Int -> value
                            is Long -> value
                            is Double -> value
                            is Boolean -> value
                            else -> value?.toString()
                        }
                }

                Log.d(TAG, "📱 Push opened: $notificationData")

                // Forward to Flutter plugin
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    val channel = MethodChannel(messenger, CHANNEL)
                    channel.invokeMethod("onPushNotificationOpened", mapOf("userInfo" to notificationData))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling notification: ${e.message}", e)
        }
    }
}
