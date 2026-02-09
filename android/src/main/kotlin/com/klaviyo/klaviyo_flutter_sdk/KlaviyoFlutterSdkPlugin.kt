package com.klaviyo.klaviyo_flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import com.google.firebase.messaging.FirebaseMessaging
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import com.klaviyo.analytics.model.Profile
import com.klaviyo.analytics.model.ProfileKey
import com.klaviyo.core.Registry
import com.klaviyo.core.utils.AdvancedAPI
import com.klaviyo.forms.InAppFormsConfig
import com.klaviyo.forms.registerForInAppForms
import com.klaviyo.forms.unregisterFromInAppForms
import com.klaviyo.location.LocationManager
import com.klaviyo.location.registerGeofencing
import com.klaviyo.location.unregisterGeofencing
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.time.Duration
import kotlin.time.Duration.Companion.INFINITE
import kotlin.time.Duration.Companion.seconds

class KlaviyoFlutterSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var applicationContext: android.content.Context
    private var activity: Activity? = null

    companion object {
        private const val TAG = "KlaviyoFlutter"
        private const val INFINITE_TIMEOUT_SENTINEL = -1
    }

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "klaviyo_sdk")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "klaviyo_events")
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onMethodCall(
        @NonNull call: MethodCall,
        @NonNull result: Result,
    ) {
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

                    val profile =
                        Profile(
                            externalId = profileJson?.get("external_id") as? String,
                            email = profileJson?.get("email") as? String,
                            phoneNumber = profileJson?.get("phone_number") as? String,
                            properties = properties.toMap(),
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

            "getEmail" -> {
                try {
                    val email = Klaviyo.getEmail()
                    result.success(email)
                } catch (e: Exception) {
                    result.error("EMAIL_ERROR", "Failed to get email", e.message)
                }
            }

            "getPhoneNumber" -> {
                try {
                    val phoneNumber = Klaviyo.getPhoneNumber()
                    result.success(phoneNumber)
                } catch (e: Exception) {
                    result.error("PHONE_ERROR", "Failed to get phone number", e.message)
                }
            }

            "getExternalId" -> {
                try {
                    val externalId = Klaviyo.getExternalId()
                    result.success(externalId)
                } catch (e: Exception) {
                    result.error("EXTERNAL_ID_ERROR", "Failed to get external ID", e.message)
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

            "setPushToken" -> {
                val token = call.argument<String>("token")

                // Validate token is not null or blank
                if (token.isNullOrBlank()) {
                    Registry.log.warning("Attempted to set null or empty push token")
                    result.error(
                        "INVALID_TOKEN",
                        "Push token cannot be null or empty",
                        mapOf("token" to token),
                    )
                    return
                }

                // Forward token to Klaviyo SDK
                // setPushToken() uses safeApply which catches exceptions internally - it never throws
                Registry.log.verbose("Setting push token: $token...")
                Klaviyo.setPushToken(token)
                result.success(null)
            }

            "getPushToken" -> {
                val token = Klaviyo.getPushToken()

                if (token != null) {
                    Registry.log.verbose("Retrieved push token from SDK: $token")
                } else {
                    Registry.log.verbose("No push token available")
                }

                result.success(token)
            }

            "registerForPushNotifications" -> {
                // Fetch the FCM token and register it with Klaviyo.
                // Return result immediately to match iOS behavior, where
                // registerForRemoteNotifications() is fire-and-forget and
                // the outcome arrives asynchronously via the event channel.
                try {
                    FirebaseMessaging
                        .getInstance()
                        .token
                        .addOnSuccessListener { token ->
                            Registry.log.verbose("FCM token received: $token")

                            // Set the token in Klaviyo SDK
                            Klaviyo.setPushToken(token)

                            // Emit the token via EventChannel
                            eventSink?.success(
                                mapOf(
                                    "type" to "push_token_received",
                                    "data" to mapOf("token" to token),
                                ),
                            )
                        }.addOnFailureListener { exception ->
                            Registry.log.error("Failed to get FCM token: ${exception.message}", exception)

                            // Emit error via EventChannel
                            eventSink?.success(
                                mapOf(
                                    "type" to "push_token_error",
                                    "data" to mapOf("error" to (exception.message ?: "Unknown error")),
                                ),
                            )
                        }
                } catch (e: Exception) {
                    Registry.log.error("Error registering for push notifications: ${e.message}", e)

                    eventSink?.success(
                        mapOf(
                            "type" to "push_token_error",
                            "data" to mapOf("error" to (e.message ?: "Unknown error")),
                        ),
                    )
                }

                result.success(null)
            }

            "registerForInAppForms" -> {
                val configuration = call.argument<Map<String, Any>>("configuration")

                try {
                    val sessionTimeout: Duration =
                        when (val timeout = configuration?.get("sessionTimeoutDuration") as? Int) {
                            null -> {
                                InAppFormsConfig.DEFAULT_SESSION_TIMEOUT.also {
                                    Registry.log.warning(
                                        "No session timeout included - defaulting to ${InAppFormsConfig.DEFAULT_SESSION_TIMEOUT}",
                                    )
                                }
                            }

                            INFINITE_TIMEOUT_SENTINEL -> {
                                INFINITE
                            }

                            else -> {
                                timeout.seconds
                            }
                        }

                    Klaviyo.registerForInAppForms(
                        InAppFormsConfig(sessionTimeoutDuration = sessionTimeout),
                    )

                    result.success(null)
                } catch (e: Exception) {
                    result.error("FORMS_ERROR", "Failed to register for in-app forms", e.message)
                }
            }

            "unregisterFromInAppForms" -> {
                try {
                    Klaviyo.unregisterFromInAppForms()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("FORMS_ERROR", "Failed to unregister from in-app forms", e.message)
                }
            }

            "registerGeofencing" -> {
                try {
                    Klaviyo.registerGeofencing()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("GEOFENCING_ERROR", "Failed to register for geofencing", e.message)
                }
            }

            "unregisterGeofencing" -> {
                try {
                    Klaviyo.unregisterGeofencing()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("GEOFENCING_ERROR", "Failed to unregister from geofencing", e.message)
                }
            }

            "getCurrentGeofences" -> {
                try {
                    // Follow the same pattern as React Native SDK
                    // Note: in the future, we may be storing more fences than we are observing
                    val geofencesArray = mutableListOf<Map<String, Any>>()

                    Registry.getOrNull<LocationManager>()?.getStoredGeofences()?.forEach { geofence ->
                        geofencesArray.add(
                            mapOf(
                                "identifier" to geofence.id,
                                "latitude" to geofence.latitude,
                                "longitude" to geofence.longitude,
                                "radius" to geofence.radius.toDouble(),
                            ),
                        )
                    } ?: run {
                        Registry.log.warning("Geofencing is not yet registered")
                    }

                    result.success(mapOf("geofences" to geofencesArray))
                } catch (e: Exception) {
                    result.error("GEOFENCING_ERROR", "Failed to get current geofences", e.message)
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

            "setBadgeCount" -> {
                // Badge count is not supported on Android in the same way as iOS
                Registry.log.verbose("setBadgeCount called - not supported on Android")
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel.setMethodCallHandler(null)
    }

    // ActivityAware implementation
    @OptIn(AdvancedAPI::class)
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity

        Registry.lifecycleMonitor.assignCurrentActivity(binding.activity)

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

    @OptIn(AdvancedAPI::class)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity

        Registry.lifecycleMonitor.assignCurrentActivity(binding.activity)

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

                Registry.log.verbose("Push notification opened: $notificationData")

                // Forward to Flutter via EventChannel
                eventSink?.success(
                    mapOf(
                        "type" to "push_notification_opened",
                        "data" to notificationData,
                    ),
                )
            }
        } catch (e: Exception) {
            Registry.log.error("Error handling push: ${e.message}", e)
        }
    }
}
