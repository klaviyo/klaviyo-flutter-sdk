package com.klaviyo.klaviyo_flutter_sdk

import com.klaviyo.analytics.Klaviyo
import com.klaviyo.analytics.model.Event
import com.klaviyo.analytics.model.EventKey
import com.klaviyo.analytics.model.EventMetric
import com.klaviyo.analytics.model.Profile
import com.klaviyo.analytics.model.ProfileKey
import com.klaviyo.analytics.model.Subscription
import com.klaviyo.core.MissingKlaviyoModule
import com.klaviyo.core.Registry
import com.klaviyo.core.config.Log
import com.klaviyo.forms.InAppFormsConfig
import com.klaviyo.forms.registerForInAppForms
import com.klaviyo.forms.registerFormLifecycleHandler
import com.klaviyo.forms.startFormsPreview
import com.klaviyo.forms.unregisterFormLifecycleHandler
import com.klaviyo.forms.unregisterFromInAppForms
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import kotlin.time.Duration.Companion.INFINITE
import kotlin.time.Duration.Companion.seconds

class KlaviyoFlutterSdkPluginMethodCallTest {
    private lateinit var plugin: KlaviyoFlutterSdkPlugin
    private lateinit var result: MethodChannel.Result
    private lateinit var log: Log

    @Before
    fun setUp() {
        log = mockk(relaxed = true)
        mockkObject(Registry)
        every { Registry.log } returns log

        mockkObject(Klaviyo)
        mockkStatic(Klaviyo::class)
        every { Klaviyo.setProfile(any()) } returns Klaviyo
        every { Klaviyo.setProfileAttribute(any(), any()) } returns Klaviyo
        every { Klaviyo.createEvent(any<Event>()) } returns Klaviyo
        every { Klaviyo.createSubscription(any()) } returns Klaviyo
        every { Klaviyo.setPushToken(any()) } returns Klaviyo

        mockkStatic("com.klaviyo.forms.InAppFormsKt")
        every { Klaviyo.registerForInAppForms(any()) } returns Klaviyo
        every { Klaviyo.unregisterFormLifecycleHandler() } returns Klaviyo
        every { Klaviyo.registerFormLifecycleHandler(any()) } returns Klaviyo

        plugin = KlaviyoFlutterSdkPlugin()
        result = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    private fun call(
        method: String,
        arguments: Map<String, Any?>? = null,
    ) = plugin.onMethodCall(MethodCall(method, arguments), result)

    @Test
    fun `setProfile maps identifiers, standard fields, location and custom properties`() {
        val profile = slot<Profile>()
        every { Klaviyo.setProfile(capture(profile)) } returns Klaviyo

        call(
            "setProfile",
            mapOf(
                "profile" to
                    mapOf(
                        "email" to "a@b.com",
                        "phone_number" to "+15555550100",
                        "external_id" to "ext-1",
                        "first_name" to "Ada",
                        "last_name" to "Lovelace",
                        "organization" to "Org",
                        "title" to "Engineer",
                        "image" to "https://example.com/a.png",
                        "location" to
                            mapOf(
                                "address1" to "1 Main St",
                                "address2" to "Apt 2",
                                "city" to "Boston",
                                "country" to "US",
                                "region" to "MA",
                                "zip" to "02110",
                                "latitude" to 42,
                                "longitude" to -71.5,
                                "timezone" to "America/New_York",
                            ),
                        "properties" to mapOf("plan" to "gold", "visits" to 3),
                    ),
            ),
        )

        verify { result.success(null) }
        with(profile.captured) {
            assertEquals("a@b.com", email)
            assertEquals("+15555550100", phoneNumber)
            assertEquals("ext-1", externalId)
            assertEquals("Ada", this[ProfileKey.FIRST_NAME])
            assertEquals("Lovelace", this[ProfileKey.LAST_NAME])
            assertEquals("Org", this[ProfileKey.ORGANIZATION])
            assertEquals("Engineer", this[ProfileKey.TITLE])
            assertEquals("https://example.com/a.png", this[ProfileKey.IMAGE])
            assertEquals("1 Main St", this[ProfileKey.ADDRESS1])
            assertEquals("Apt 2", this[ProfileKey.ADDRESS2])
            assertEquals("Boston", this[ProfileKey.CITY])
            assertEquals("US", this[ProfileKey.COUNTRY])
            assertEquals("MA", this[ProfileKey.REGION])
            assertEquals("02110", this[ProfileKey.ZIP])
            assertEquals(42.0, this[ProfileKey.LATITUDE])
            assertEquals(-71.5, this[ProfileKey.LONGITUDE])
            assertEquals("America/New_York", this[ProfileKey.TIMEZONE])
            assertEquals("gold", this[ProfileKey.CUSTOM("plan")])
            assertEquals(3, this[ProfileKey.CUSTOM("visits")])
        }
    }

    @Test
    fun `setProfile reports PROFILE_ERROR when the native SDK throws`() {
        every { Klaviyo.setProfile(any()) } throws IllegalStateException("boom")

        call("setProfile", mapOf("profile" to mapOf("email" to "a@b.com")))

        verify { result.error("PROFILE_ERROR", "Failed to set profile", "boom") }
    }

    @Test
    fun `setProfileProperties sets each value as a custom attribute`() {
        call("setProfileProperties", mapOf("properties" to mapOf("plan" to "gold", "visits" to 3)))

        verify { Klaviyo.setProfileAttribute(ProfileKey.CUSTOM("plan"), "gold") }
        verify { Klaviyo.setProfileAttribute(ProfileKey.CUSTOM("visits"), 3) }
        verify { result.success(null) }
    }

    @Test
    fun `trackEvent maps name, properties, value, currency and unique id`() {
        val event = slot<Event>()
        every { Klaviyo.createEvent(capture(event)) } returns Klaviyo

        call(
            "trackEvent",
            mapOf(
                "event" to
                    mapOf(
                        "name" to "Added to Cart",
                        "properties" to mapOf("sku" to "A1"),
                        "value" to 9,
                        "value_currency" to "USD",
                        "unique_id" to "u-1",
                    ),
            ),
        )

        verify { result.success(null) }
        with(event.captured) {
            assertEquals(EventMetric.CUSTOM("Added to Cart").name, metric.name)
            assertEquals("A1", this[EventKey.CUSTOM("sku")])
            assertEquals(9.0, value)
            assertEquals("USD", valueCurrency)
            assertEquals("u-1", uniqueId)
        }
    }

    @Test
    fun `trackEvent without a name reports TRACK_ERROR`() {
        call("trackEvent", mapOf("event" to mapOf("value" to 1)))

        verify { result.error("TRACK_ERROR", "Failed to track event", any()) }
        verify(exactly = 0) { Klaviyo.createEvent(any<Event>()) }
    }

    @Test
    fun `createSubscription without channels requests all available marketing`() {
        val subscription = slot<Subscription>()
        every { Klaviyo.createSubscription(capture(subscription)) } returns Klaviyo

        call(
            "createSubscription",
            mapOf("subscription" to mapOf("listId" to "L1", "customSource" to "Footer")),
        )

        verify { result.success(null) }
        val expected = Subscription.allAvailableMarketing("L1", "Footer")
        assertEquals(expected.listId, subscription.captured.listId)
        assertEquals(expected.customSource, subscription.captured.customSource)
        assertEquals(expected.channels?.email, subscription.captured.channels?.email)
        assertEquals(expected.channels?.sms, subscription.captured.channels?.sms)
        assertEquals(expected.channels?.whatsapp, subscription.captured.channels?.whatsapp)
    }

    @Test
    fun `createSubscription maps each channel's consent wire values`() {
        val subscription = slot<Subscription>()
        every { Klaviyo.createSubscription(capture(subscription)) } returns Klaviyo

        call(
            "createSubscription",
            mapOf(
                "subscription" to
                    mapOf(
                        "listId" to "L1",
                        "channels" to
                            mapOf(
                                "email" to listOf("marketing", "open_tracking"),
                                "sms" to emptyList<String>(),
                            ),
                    ),
            ),
        )

        verify { result.success(null) }
        val channels = subscription.captured.channels!!
        assertEquals(
            setOf(Subscription.Channels.Email.MARKETING, Subscription.Channels.Email.OPEN_TRACKING),
            channels.email,
        )
        assertEquals(emptySet<Subscription.Channels.Messaging>(), channels.sms)
        assertNull(channels.whatsapp)
        assertNull(subscription.captured.customSource)
    }

    @Test
    fun `createSubscription with an unknown consent value reports SUBSCRIPTION_ERROR`() {
        call(
            "createSubscription",
            mapOf(
                "subscription" to
                    mapOf(
                        "listId" to "L1",
                        "channels" to mapOf("whatsapp" to listOf("carrier_pigeon")),
                    ),
            ),
        )

        verify { result.error("SUBSCRIPTION_ERROR", "Failed to create subscription", any()) }
        verify(exactly = 0) { Klaviyo.createSubscription(any()) }
    }

    @Test
    fun `createSubscription with a blank list id reports SUBSCRIPTION_ERROR`() {
        call("createSubscription", mapOf("subscription" to mapOf("listId" to " ")))

        verify {
            result.error("SUBSCRIPTION_ERROR", "Subscription listId cannot be null or empty", null)
        }
        verify(exactly = 0) { Klaviyo.createSubscription(any()) }
    }

    @Test
    fun `setPushToken forwards a token and rejects a blank one`() {
        call("setPushToken", mapOf("token" to "tok"))
        verify { Klaviyo.setPushToken("tok") }
        verify { result.success(null) }

        call("setPushToken", mapOf("token" to ""))
        verify { result.error("INVALID_TOKEN", "Push token cannot be null or empty", mapOf("token" to "")) }
        verify(exactly = 1) { Klaviyo.setPushToken(any()) }
    }

    @Test
    fun `registerForInAppForms maps the session timeout sentinel values`() {
        val configs = mutableListOf<InAppFormsConfig>()
        every { Klaviyo.registerForInAppForms(capture(configs)) } returns Klaviyo

        call("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to 30)))
        call("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to -1)))
        call("registerForInAppForms", mapOf("configuration" to mapOf("sessionTimeoutDuration" to 0)))
        call("registerForInAppForms", mapOf("configuration" to null))

        assertEquals(
            listOf(30.seconds, INFINITE, 0.seconds, InAppFormsConfig.DEFAULT_SESSION_TIMEOUT)
                .map { InAppFormsConfig(sessionTimeoutDuration = it) },
            configs,
        )
        verify(exactly = 4) { result.success(null) }
        verify(exactly = 4) { Klaviyo.unregisterFormLifecycleHandler() }
        verify(exactly = 4) { Klaviyo.registerFormLifecycleHandler(any()) }
    }

    @Test
    fun `forms calls report FORMS_NOT_AVAILABLE when the forms module is missing`() {
        every { Klaviyo.registerForInAppForms(any()) } throws MissingKlaviyoModule("forms")
        every { Klaviyo.startFormsPreview(any()) } throws MissingKlaviyoModule("forms")
        every { Klaviyo.unregisterFromInAppForms() } throws MissingKlaviyoModule("forms")

        call("registerForInAppForms", mapOf("configuration" to null))
        call("startFormsPreview", mapOf("token" to "t"))
        call("unregisterFromInAppForms")

        verify(exactly = 3) { result.error("FORMS_NOT_AVAILABLE", any(), null) }
    }

    @Test
    fun `startFormsPreview without a token reports INVALID_ARGUMENTS`() {
        call("startFormsPreview", emptyMap())

        verify { result.error("INVALID_ARGUMENTS", "A forms preview token is required", null) }
        verify(exactly = 0) { Klaviyo.startFormsPreview(any()) }
    }

    @Test
    fun `startFormsPreview failures do not echo the token`() {
        every { Klaviyo.startFormsPreview(any()) } throws IllegalStateException("bad token secret-token")

        call("startFormsPreview", mapOf("token" to "secret-token"))

        verify { result.error("FORMS_ERROR", "Failed to start the forms preview", null) }
    }

    @Test
    fun `setLoggingEnabled disables and restores the previous level`() {
        var level = Log.Level.Info
        every { log.logLevel } answers { level }
        every { log.logLevel = any() } answers { level = firstArg() }

        call("setLoggingEnabled", mapOf("enabled" to false))
        assertEquals(Log.Level.None, level)
        call("isLoggingEnabled")
        verify { result.success(false) }

        call("setLoggingEnabled", mapOf("enabled" to false))
        call("setLoggingEnabled", mapOf("enabled" to true))
        assertEquals(Log.Level.Info, level)
        call("isLoggingEnabled")
        verify { result.success(true) }
    }

    @Test
    fun `setLoggingEnabled leaves an enabled level alone when enabling`() {
        var level = Log.Level.Debug
        every { log.logLevel } answers { level }
        every { log.logLevel = any() } answers { level = firstArg() }

        call("setLoggingEnabled", mapOf("enabled" to true))

        assertEquals(Log.Level.Debug, level)
        verify { result.success(null) }
    }

    @Test
    fun `setLoggingEnabled without the flag reports INVALID_ARGUMENTS`() {
        call("setLoggingEnabled", emptyMap())

        verify { result.error("INVALID_ARGUMENTS", "Invalid arguments for setLoggingEnabled", null) }
    }

    @Test
    fun `respondToAuthTokenRequest without an id reports INVALID_ARGUMENTS`() {
        call("respondToAuthTokenRequest", mapOf("jwt" to "token"))

        verify { result.error("INVALID_ARGUMENTS", "Missing auth token request id", null) }
    }

    @Test
    fun `respondToAuthTokenRequest for an unknown id succeeds without doing anything`() {
        call("respondToAuthTokenRequest", mapOf("id" to "nope", "jwt" to "token"))

        verify { result.success(null) }
    }

    @Test
    fun `handleUniversalTrackingLink returns the native verdict`() {
        every { Klaviyo.handleUniversalTrackingLink(any<String>()) } returns true

        call("handleUniversalTrackingLink", mapOf("url" to "https://trk.example.com/u/abc"))

        verify { result.success(true) }
    }

    @Test
    fun `initialize reports INIT_ERROR when the key is missing`() {
        call("initialize", emptyMap())

        verify { result.error("INIT_ERROR", "Failed to initialize Klaviyo", any()) }
    }
}
