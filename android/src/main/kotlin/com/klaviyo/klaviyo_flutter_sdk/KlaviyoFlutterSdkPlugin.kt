package com.klaviyo.klaviyo_flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.google.firebase.messaging.FirebaseMessaging
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.Klaviyo.isKlaviyoNotificationIntent
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import com.klaviyo.analytics.model.Profile
import com.klaviyo.analytics.model.ProfileKey
import com.klaviyo.core.Constants
import com.klaviyo.core.MissingKlaviyoModule
import com.klaviyo.core.Registry
import com.klaviyo.core.auth.AuthTokenProvider
import com.klaviyo.core.utils.AdvancedAPI
import com.klaviyo.forms.FormLifecycleEvent
import com.klaviyo.forms.InAppFormsConfig
import com.klaviyo.forms.registerForInAppForms
import com.klaviyo.forms.registerFormLifecycleHandler
import com.klaviyo.forms.unregisterFormLifecycleHandler
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
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
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

    /**
     * Pending auth token requests keyed by correlation ID. The native SDK
     * invokes the provider on a background dispatcher and hands us an
     * [AuthTokenProvider.Callback] to complete once the Dart side responds via
     * `respondToAuthTokenRequest`. Each entry is tagged with the registration
     * [PendingAuthRequest.generation] it belongs to. The token itself is never
     * logged here; all token logging happens in the native SDK.
     */
    private val pendingAuthCallbacks = ConcurrentHashMap<String, PendingAuthRequest>()

    /**
     * Monotonic registration generation, bumped on every register and
     * unregister (both on the main/method-channel thread). A pending request
     * carries the generation captured when its provider was registered; if that
     * no longer matches [authTokenGeneration] at response time, the provider was
     * torn down or replaced while the request was in flight, and the request is
     * failed rather than answered with a different registration's token.
     */
    private var authTokenGeneration = 0

    private data class PendingAuthRequest(
        val callback: AuthTokenProvider.Callback,
        val generation: Int,
    )

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

                try {
                    // Initialize Klaviyo SDK
                    Klaviyo.initialize(apiKey!!, applicationContext)
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

                    // Add location properties if present
                    (profileJson?.get("location") as? Map<String, Any>)?.let { locationData ->
                        (locationData["address1"] as? String)?.let { properties[ProfileKey.ADDRESS1] = it }
                        (locationData["address2"] as? String)?.let { properties[ProfileKey.ADDRESS2] = it }
                        (locationData["city"] as? String)?.let { properties[ProfileKey.CITY] = it }
                        (locationData["country"] as? String)?.let { properties[ProfileKey.COUNTRY] = it }
                        (locationData["region"] as? String)?.let { properties[ProfileKey.REGION] = it }
                        (locationData["zip"] as? String)?.let { properties[ProfileKey.ZIP] = it }
                        (locationData["latitude"] as? Number)?.let { properties[ProfileKey.LATITUDE] = it.toDouble() }
                        (locationData["longitude"] as? Number)?.let { properties[ProfileKey.LONGITUDE] = it.toDouble() }
                        (locationData["timezone"] as? String)?.let { properties[ProfileKey.TIMEZONE] = it }
                    }

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

                    // Add uniqueId if provided
                    (eventJson?.get("unique_id") as? String)?.let { uniqueId ->
                        event = event.setUniqueId(uniqueId)
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
                try {
                    val configuration = call.argument<Map<String, Any>>("configuration")

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

                    // Unregister any existing handler to prevent duplicates
                    Klaviyo.unregisterFormLifecycleHandler()

                    // Register form lifecycle handler
                    Klaviyo.registerFormLifecycleHandler { event ->
                        val data =
                            mutableMapOf<String, Any>(
                                "formId" to event.formId,
                                "formName" to event.formName,
                            )

                        when (event) {
                            is FormLifecycleEvent.FormShown -> {
                                data["event"] = "formShown"
                            }

                            is FormLifecycleEvent.FormDismissed -> {
                                data["event"] = "formDismissed"
                            }

                            is FormLifecycleEvent.FormCtaClicked -> {
                                data["event"] = "formCtaClicked"
                                data["buttonLabel"] = event.buttonLabel
                                data["deepLinkUrl"] = event.deepLinkUrl.toString()
                            }
                        }

                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(
                                mapOf(
                                    "type" to "form_lifecycle_event",
                                    "data" to data,
                                ),
                            )
                        }
                    }

                    result.success(null)
                } catch (e: MissingKlaviyoModule) {
                    Registry.log.error("Forms not available: forms module not included", e)
                    result.error("FORMS_NOT_AVAILABLE", e.message, null)
                } catch (e: Exception) {
                    result.error("FORMS_ERROR", "Failed to register for in-app forms", e.message)
                }
            }

            "unregisterFromInAppForms" -> {
                try {
                    Klaviyo.unregisterFormLifecycleHandler()
                    Klaviyo.unregisterFromInAppForms()
                    result.success(null)
                } catch (e: MissingKlaviyoModule) {
                    Registry.log.error("Forms not available: forms module not included", e)
                    result.error("FORMS_NOT_AVAILABLE", e.message, null)
                } catch (e: Exception) {
                    result.error("FORMS_ERROR", "Failed to unregister from in-app forms", e.message)
                }
            }

            "registerGeofencing" -> {
                try {
                    Klaviyo.registerGeofencing()
                    result.success(null)
                } catch (e: MissingKlaviyoModule) {
                    Registry.log.error("Geofencing not available: location module not included", e)
                    result.error(
                        "GEOFENCING_NOT_AVAILABLE",
                        "Geofencing requires the full location module. Add 'klaviyoIncludeLocation=true' to gradle.properties",
                        e.message,
                    )
                } catch (e: Exception) {
                    Registry.log.error("Failed to register for geofencing: ${e.message}", e)
                    result.error("GEOFENCING_ERROR", "Failed to register for geofencing", e.message)
                }
            }

            "unregisterGeofencing" -> {
                try {
                    Klaviyo.unregisterGeofencing()
                    result.success(null)
                } catch (e: MissingKlaviyoModule) {
                    Registry.log.error("Geofencing not available: location module not included", e)
                    result.error(
                        "GEOFENCING_NOT_AVAILABLE",
                        "Geofencing requires the full location module. Add 'klaviyoIncludeLocation=true' to gradle.properties",
                        e.message,
                    )
                } catch (e: Exception) {
                    Registry.log.error("Failed to unregister from geofencing: ${e.message}", e)
                    result.error("GEOFENCING_ERROR", "Failed to unregister from geofencing", e.message)
                }
            }

            "getCurrentGeofences" -> {
                try {
                    val locationManager = Registry.getOrNull<LocationManager>()

                    if (locationManager == null) {
                        Registry.log.error("Geofencing not available: location module not included")
                        result.error(
                            "GEOFENCING_NOT_AVAILABLE",
                            "Geofencing requires the full location module. Add 'klaviyoIncludeLocation=true' to gradle.properties",
                            null,
                        )
                        return
                    }

                    // Follow the same pattern as React Native SDK
                    // Note: in the future, we may be storing more fences than we are observing
                    val geofencesArray = mutableListOf<Map<String, Any>>()

                    locationManager.getStoredGeofences()?.forEach { geofence ->
                        geofencesArray.add(
                            mapOf(
                                "identifier" to geofence.id,
                                "latitude" to geofence.latitude,
                                "longitude" to geofence.longitude,
                                "radius" to geofence.radius.toDouble(),
                            ),
                        )
                    }

                    result.success(mapOf("geofences" to geofencesArray))
                } catch (e: Exception) {
                    Registry.log.error("Failed to get current geofences: ${e.message}", e)
                    result.error("GEOFENCING_ERROR", "Failed to get current geofences", e.message)
                }
            }

            "registerAuthTokenProvider" -> {
                try {
                    // Capture this registration's generation now (main thread). The
                    // lambda closes over it by value, so even though the SDK invokes
                    // the lambda on a background dispatcher, it never races on shared
                    // generation state.
                    val generation = ++authTokenGeneration
                    Klaviyo.registerAuthTokenProvider { callback ->
                        // The native SDK keeps at most one token fetch in flight, so any
                        // entries still pending when a NEW request arrives belong to a
                        // previous fetch it has already abandoned (e.g. timed out). Android's
                        // callback API gives no per-request timeout hook (unlike iOS's
                        // withTaskCancellationHandler onCancel), so this is where stale ids
                        // are reclaimed — bounding the map and honoring the "timed-out ids
                        // don't resolve" contract.
                        failAllPendingAuthCallbacks("Superseded by a newer auth token request")
                        val id = UUID.randomUUID().toString()
                        pendingAuthCallbacks[id] = PendingAuthRequest(callback, generation)
                        emitAuthTokenRequest(id)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    Registry.log.error("Failed to register auth token provider", e)
                    result.error("AUTH_TOKEN_ERROR", "Failed to register auth token provider", e.message)
                }
            }

            "unregisterAuthTokenProvider" -> {
                try {
                    Klaviyo.unregisterAuthTokenProvider()
                    result.success(null)
                } catch (e: Exception) {
                    Registry.log.error("Failed to unregister auth token provider", e)
                    result.error("AUTH_TOKEN_ERROR", "Failed to unregister auth token provider", e.message)
                } finally {
                    // Bump the generation so any request stored by an in-flight
                    // provider callback that races this teardown is treated as stale
                    // at response time. Then fail and drop any requests still
                    // awaiting a Dart response so no callbacks dangle.
                    ++authTokenGeneration
                    failAllPendingAuthCallbacks("Auth token provider was unregistered")
                }
            }

            "respondToAuthTokenRequest" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("INVALID_ARGUMENTS", "Missing auth token request id", null)
                    return
                }

                val pending = pendingAuthCallbacks.remove(id)
                if (pending == null) {
                    // Unknown, already-resolved, or timed-out request. Nothing to do.
                    Registry.log.verbose("No pending auth token request for id $id")
                    result.success(null)
                    return
                }

                if (pending.generation != authTokenGeneration) {
                    // The provider was unregistered/replaced while this request was in
                    // flight, so it belongs to a superseded registration. Fail it
                    // rather than answer it with a different registration's token.
                    pending.callback.onFailure(
                        IllegalStateException("Auth token request superseded by re-registration"),
                    )
                    result.success(null)
                    return
                }

                val callback = pending.callback
                val jwt = call.argument<String>("jwt")
                if (jwt != null) {
                    callback.onSuccess(jwt)
                } else {
                    val message = call.argument<String>("error") ?: "Auth token provider returned no token"
                    val isConnectivityError = call.argument<Boolean>("isConnectivityError") ?: false
                    // Surface connectivity failures as an IOException so the SDK's
                    // connectivity-driven retry classifier recognizes them; other
                    // failures use a generic Throwable, which the SDK treats as
                    // non-retryable.
                    if (isConnectivityError) {
                        callback.onFailure(IOException(message))
                    } else {
                        callback.onFailure(Throwable(message))
                    }
                }
                result.success(null)
            }

            "resetProfile" -> {
                try {
                    Klaviyo.resetProfile()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("RESET_ERROR", "Failed to reset profile", e.message)
                }
            }

            "setBadgeCount" -> {
                // Badge count is not supported on Android in the same way as iOS
                Registry.log.verbose("setBadgeCount called - not supported on Android")
                result.success(null)
            }

            "handleUniversalTrackingLink" -> {
                val url = call.argument<String>("url")

                try {
                    if (url == null) {
                        result.error("INVALID_URL", "URL cannot be null", null)
                        return
                    }

                    val isKlaviyoLink = Klaviyo.handleUniversalTrackingLink(url)
                    result.success(isKlaviyoLink)
                } catch (e: Exception) {
                    result.error("DEEP_LINK_ERROR", "Failed to handle universal tracking link", e.message)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Emits an `auth_token_requested` event to Dart, resolving the event sink
     * and handling delivery failure *inside* the main-thread runnable.
     *
     * The sink is read at execution time (not when scheduling) because it can be
     * cancelled between `post()` and the runnable actually running; and
     * `EventSink.success` can throw. In either case the pending callback for
     * [id] is removed and failed here, so a request never dangles until the
     * native SDK timeout and the map never leaks. The token itself is never
     * logged — only the correlation id crosses this event.
     */
    private fun emitAuthTokenRequest(id: String) {
        Handler(Looper.getMainLooper()).post {
            val sink = eventSink
            if (sink == null) {
                pendingAuthCallbacks.remove(id)?.callback?.onFailure(
                    IllegalStateException(
                        "Unable to reach the Dart auth token provider (event sink unavailable)",
                    ),
                )
                return@post
            }
            try {
                sink.success(
                    mapOf(
                        "type" to "auth_token_requested",
                        "data" to mapOf("id" to id),
                    ),
                )
            } catch (e: Exception) {
                Registry.log.error("Failed to emit auth token request", e)
                pendingAuthCallbacks.remove(id)?.callback?.onFailure(
                    IllegalStateException("Failed to deliver auth token request to Dart", e),
                )
            }
        }
    }

    /** Fails and drops every pending auth token callback. */
    private fun failAllPendingAuthCallbacks(reason: String) {
        pendingAuthCallbacks.keys.toList().forEach { id ->
            pendingAuthCallbacks.remove(id)?.callback?.onFailure(IllegalStateException(reason))
        }
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel.setMethodCallHandler(null)
        eventSink = null
        // Unregister the auth token provider so the Klaviyo singleton stops
        // retaining (and invoking) this now-detached plugin instance's bridge
        // lambda after the engine is gone. Fail pending callbacks in a finally
        // so they're always drained even if unregister throws.
        try {
            Klaviyo.unregisterAuthTokenProvider()
        } catch (e: Exception) {
            Registry.log.warning("Failed to unregister auth token provider on detach: ${e.message}")
        } finally {
            failAllPendingAuthCallbacks("Flutter engine detached")
        }
        try {
            Klaviyo.unregisterFormLifecycleHandler()
        } catch (_: MissingKlaviyoModule) {
            Registry.log.verbose("Forms lifecycle handler not available during cleanup: forms module not included")
        } catch (e: Exception) {
            Registry.log.warning("Unexpected error during cleanup: ${e.message}")
        }
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

            val extras = intent.extras
            if (extras != null && intent.isKlaviyoNotificationIntent) {
                // Klaviyo namespaces all push extras with Constants.PACKAGE_PREFIX when building
                // the tap PendingIntent. Strip it so the Dart payload matches the iOS userInfo shape.
                val notificationData = mutableMapOf<String, Any?>()
                for (key in extras.keySet()) {
                    if (!key.startsWith(Constants.PACKAGE_PREFIX)) continue
                    val unprefixedKey = key.removePrefix(Constants.PACKAGE_PREFIX)
                    val value = extras.get(key)
                    notificationData[unprefixedKey] =
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
