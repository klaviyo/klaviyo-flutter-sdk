package com.klaviyo.klaviyo_flutter_sdk

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.model.Profile
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.PushToken
import com.klaviyo.analytics.model.InAppForm
import org.json.JSONObject
import org.json.JSONArray

class KlaviyoFlutterSdkPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var eventSink: EventChannel.EventSink
  private lateinit var applicationContext: android.content.Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
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
          val profile = Profile.Builder()
            .email(profileJson?.get("email") as? String)
            .phoneNumber(profileJson?.get("phone_number") as? String)
            .externalId(profileJson?.get("external_id") as? String)
            .firstName(profileJson?.get("first_name") as? String)
            .lastName(profileJson?.get("last_name") as? String)
            .organization(profileJson?.get("organization") as? String)
            .title(profileJson?.get("title") as? String)
            .image(profileJson?.get("image") as? String)
            .build()
          
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
          Klaviyo.setProfileProperties(properties!!)
          result.success(null)
        } catch (e: Exception) {
          result.error("PROPERTIES_ERROR", "Failed to set profile properties", e.message)
        }
      }
      
      "trackEvent" -> {
        val eventJson = call.argument<Map<String, Any>>("event")
        try {
          val event = Event.Builder()
            .name(eventJson?.get("name") as String)
            .properties(eventJson?.get("properties") as? Map<String, Any>)
            .timestamp(eventJson?.get("timestamp") as? String)
            .build()
          
          Klaviyo.trackEvent(event)
          result.success(null)
        } catch (e: Exception) {
          result.error("TRACK_ERROR", "Failed to track event", e.message)
        }
      }
      
      "registerForPushNotifications" -> {
        try {
          Klaviyo.registerForPushNotifications()
          result.success(null)
        } catch (e: Exception) {
          result.error("PUSH_REGISTER_ERROR", "Failed to register for push notifications", e.message)
        }
      }
      
      "setPushToken" -> {
        val token = call.argument<String>("token")
        val environment = call.argument<String>("environment")
        
        try {
          val pushToken = PushToken.Builder()
            .token(token!!)
            .environment(environment ?: "production")
            .build()
          
          Klaviyo.setPushToken(pushToken)
          result.success(null)
        } catch (e: Exception) {
          result.error("PUSH_TOKEN_ERROR", "Failed to set push token", e.message)
        }
      }
      
      "getPushToken" -> {
        try {
          // The SDK doesn't provide a direct method to get the push token
          // This would need to be managed by the Flutter app
          result.success(mapOf(
            "token" to "",
            "environment" to "production",
            "platform" to "android",
            "createdAt" to System.currentTimeMillis().toString(),
            "isActive" to false
          ))
        } catch (e: Exception) {
          result.error("PUSH_TOKEN_ERROR", "Failed to get push token", e.message)
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
} 