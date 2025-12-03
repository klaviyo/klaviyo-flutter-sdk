package com.klaviyo.klaviyo_flutter_sdk

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.model.Profile
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.ProfileKey
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import org.json.JSONObject
import org.json.JSONArray

class KlaviyoFlutterSdkPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var eventSink: EventChannel.EventSink
  private lateinit var applicationContext: android.content.Context
  private var activity: Activity? = null
  private lateinit var sharedPreferences: SharedPreferences

  companion object {
    private const val PREFS_NAME = "KlaviyoFlutterSDKPrefs"
    private const val KEY_PUSH_TOKEN = "push_token"
    private const val KEY_TOKEN_TIMESTAMP = "token_timestamp"
    private const val TAG = "KlaviyoFlutter"
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    sharedPreferences = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "klaviyo_sdk")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "klaviyo_events")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events!!
      }

      override fun onCancel(arguments: Any?) {
        // Handle cancellation
      }
    })
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "initialize" -> {
        val apiKey = call.argument<String>("apiKey")
        val environment = call.argument<String>("environment")
        val configuration = call.argument<Map<String, Any>>("configuration")
        
        try {
          // Initialize Klaviyo SDK
          Klaviyo.initialize(apiKey!!, applicationContext)
          
          // Apply configuration if provided
          configuration?.let { config ->
            // Handle configuration options
          }
          
          result.success(null)
        } catch (e: Exception) {
          result.error("INIT_ERROR", "Failed to initialize Klaviyo", e.message)
        }
      }
      
      "setProfile" -> {
        val profileJson = call.argument<Map<String, Any>>("profile")
        try {
          // Build properties map for custom fields
          val properties = mutableMapOf<ProfileKey, java.io.Serializable>()
          (profileJson?.get("first_name") as? String)?.let { properties[ProfileKey.FIRST_NAME] = it }
          (profileJson?.get("last_name") as? String)?.let { properties[ProfileKey.LAST_NAME] = it }
          (profileJson?.get("organization") as? String)?.let { properties[ProfileKey.ORGANIZATION] = it }
          (profileJson?.get("title") as? String)?.let { properties[ProfileKey.TITLE] = it }
          (profileJson?.get("image") as? String)?.let { properties[ProfileKey.IMAGE] = it }

          // Add any custom properties from the properties field
          (profileJson?.get("properties") as? Map<String, Any>)?.forEach { (key, value) ->
            if (value is java.io.Serializable) {
              properties[ProfileKey.CUSTOM(key)] = value
            }
          }

          val profile = Profile(
            externalId = profileJson?.get("external_id") as? String,
            email = profileJson?.get("email") as? String,
            phoneNumber = profileJson?.get("phone_number") as? String,
            properties = properties.toMap()
          )

          Klaviyo.setProfile(profile)
          result.success(null)
        } catch (e: Exception) {
          result.error("PROFILE_ERROR", "Failed to set profile", e.message)
        }
      }
      
      "setEmail" -> {
        val email = call.argument<String>("email")
        try {
          Klaviyo.setEmail(email!!)
          result.success(null)
        } catch (e: Exception) {
          result.error("EMAIL_ERROR", "Failed to set email", e.message)
        }
      }
      
      "setPhoneNumber" -> {
        val phoneNumber = call.argument<String>("phoneNumber")
        try {
          Klaviyo.setPhoneNumber(phoneNumber!!)
          result.success(null)
        } catch (e: Exception) {
          result.error("PHONE_ERROR", "Failed to set phone number", e.message)
        }
      }
      
      "setExternalId" -> {
        val externalId = call.argument<String>("externalId")
        try {
          Klaviyo.setExternalId(externalId!!)
          result.success(null)
        } catch (e: Exception) {
          result.error("EXTERNAL_ID_ERROR", "Failed to set external ID", e.message)
        }
      }
      
      "setProfileProperties" -> {
        val properties = call.argument<Map<String, Any>>("properties")
        try {
          // Set each property individually using setProfileAttribute
          properties?.forEach { (key, value) ->
            if (value is java.io.Serializable) {
              Klaviyo.setProfileAttribute(ProfileKey.CUSTOM(key), value)
            }
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("PROPERTIES_ERROR", "Failed to set profile properties", e.message)
        }
      }
      
      "trackEvent" -> {
        val eventJson = call.argument<Map<String, Any>>("event")
        try {
          val eventName = eventJson?.get("name") as String
          var event = Event(EventMetric.CUSTOM(eventName))

          // Add properties if provided
          (eventJson?.get("properties") as? Map<String, Any>)?.forEach { (key, value) ->
            if (value is java.io.Serializable) {
              event = event.setProperty(EventKey.CUSTOM(key), value)
            }
          }

          // Add value if provided
          (eventJson?.get("value") as? Number)?.let { value ->
            event = event.setValue(value.toDouble())
          }

          Klaviyo.createEvent(event)
          result.success(null)
        } catch (e: Exception) {
          result.error("TRACK_ERROR", "Failed to track event", e.message)
        }
      }
      
      "registerForPushNotifications" -> {
        try {
          // On Android, push registration is handled by Firebase
          // The app should handle FCM token via FirebaseMessaging.getInstance().token
          // and then call setPushToken
          result.success(null)
        } catch (e: Exception) {
          result.error("PUSH_REGISTER_ERROR", "Failed to register for push notifications", e.message)
        }
      }
      
      "setPushToken" -> {
        val token = call.argument<String>("token")

        try {
          // Klaviyo.setPushToken takes a String token directly
          Klaviyo.setPushToken(token!!)
          result.success(null)
        } catch (e: Exception) {
          result.error("PUSH_TOKEN_ERROR", "Failed to set push token", e.message)
        }
      }
      
      "getPushToken" -> {
        try {
          val token = sharedPreferences.getString(KEY_PUSH_TOKEN, "") ?: ""
          val timestamp = sharedPreferences.getLong(KEY_TOKEN_TIMESTAMP, 0L)

          result.success(mapOf(
            "token" to token,
            "environment" to "production",
            "platform" to "android",
            "createdAt" to timestamp.toString(),
            "isActive" to token.isNotEmpty()
          ))
        } catch (e: Exception) {
          result.error("PUSH_TOKEN_ERROR", "Failed to get push token", e.message)
        }
      }

      "onPushTokenReceived" -> {
        val token = call.argument<String>("token")

        try {
          if (token != null) {
            // Store token in SharedPreferences
            sharedPreferences.edit().apply {
              putString(KEY_PUSH_TOKEN, token)
              putLong(KEY_TOKEN_TIMESTAMP, System.currentTimeMillis())
              apply()
            }

            Log.d(TAG, "FCM token stored: $token")
            result.success(null)
          } else {
            result.error("TOKEN_ERROR", "Token cannot be null", null)
          }
        } catch (e: Exception) {
          result.error("TOKEN_STORAGE_ERROR", "Failed to store token", e.message)
        }
      }

      "onPushNotificationOpened" -> {
        val userInfo = call.argument<Map<String, Any>>("userInfo")

        try {
          Log.d(TAG, "Push opened: $userInfo")

          // Forward to Flutter via EventChannel
          if (::eventSink.isInitialized) {
            eventSink.success(mapOf(
              "type" to "push_notification_opened",
              "data" to userInfo
            ))
          }

          result.success(null)
        } catch (e: Exception) {
          result.error("PUSH_OPEN_ERROR", "Failed to handle push open", e.message)
        }
      }
      
      "registerForInAppForms" -> {
        val configuration = call.argument<Map<String, Any>>("configuration")
        
        try {
          // In-app forms registration is handled automatically by the SDK
          result.success(null)
        } catch (e: Exception) {
          result.error("FORMS_ERROR", "Failed to register for in-app forms", e.message)
        }
      }
      
      "showForm" -> {
        val formId = call.argument<String>("formId")
        val customData = call.argument<Map<String, Any>>("customData")
        
        try {
          // In-app forms are handled automatically by the SDK
          // This method is not directly available in the Android SDK
          result.success(true)
        } catch (e: Exception) {
          result.error("FORM_ERROR", "Failed to show form", e.message)
        }
      }
      
      "hideForm" -> {
        val formId = call.argument<String>("formId")
        
        try {
          // In-app forms are handled automatically by the SDK
          // This method is not directly available in the Android SDK
          result.success(true)
        } catch (e: Exception) {
          result.error("FORM_ERROR", "Failed to hide form", e.message)
        }
      }
      
      "resetProfile" -> {
        try {
          Klaviyo.resetProfile()
          result.success(null)
        } catch (e: Exception) {
          result.error("RESET_ERROR", "Failed to reset profile", e.message)
        }
      }
      
      "setLogLevel" -> {
        val logLevel = call.argument<String>("logLevel")
        
        try {
          // Log level is typically set during initialization
          // This method is not directly available in the Android SDK
          result.success(null)
        } catch (e: Exception) {
          result.error("LOG_LEVEL_ERROR", "Failed to set log level", e.message)
        }
      }
      
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  // ActivityAware implementation
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity

    // Handle the intent that launched this activity (cold start)
    binding.activity.intent?.let { intent ->
      handleIntent(intent)
    }

    // Listen for new intents (warm start)
    binding.addOnNewIntentListener { intent ->
      handleIntent(intent)
      false // Return false to allow other listeners
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity

    binding.addOnNewIntentListener { intent ->
      handleIntent(intent)
      false
    }
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  private fun handleIntent(intent: Intent) {
    try {
      // Let Klaviyo SDK handle push notification opens
      Klaviyo.handlePush(intent)

      // Extract notification data from the intent
      val extras = intent.extras
      if (extras != null && extras.containsKey("_k")) {
        // This is a Klaviyo push notification
        val notificationData = mutableMapOf<String, Any?>()

        // Extract all extras from the notification
        for (key in extras.keySet()) {
          val value = extras.get(key)
          notificationData[key] = when (value) {
            is String -> value
            is Int -> value
            is Long -> value
            is Double -> value
            is Boolean -> value
            else -> value?.toString()
          }
        }

        Log.d(TAG, "Push notification opened: $notificationData")

        // Forward to Flutter via EventChannel
        if (::eventSink.isInitialized) {
          eventSink.success(mapOf(
            "type" to "push_notification_opened",
            "data" to notificationData
          ))
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error handling push: ${e.message}", e)
    }
  }
} 