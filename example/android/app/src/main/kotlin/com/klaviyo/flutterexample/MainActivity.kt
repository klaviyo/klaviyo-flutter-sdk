package com.klaviyo.flutterexample

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.klaviyo.analytics.Klaviyo
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    @Suppress("ktlint:standard:property-naming")
    private val TAG = "MainActivity"

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
        } catch (e: Exception) {
            Log.e(TAG, "Error handling notification: ${e.message}", e)
        }
    }
}
