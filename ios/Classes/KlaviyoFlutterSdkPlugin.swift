// swiftlint:disable file_length
import Flutter
#if canImport(KlaviyoForms)
import KlaviyoForms
#endif
import KlaviyoSwift
#if canImport(KlaviyoLocation)
@_spi(KlaviyoPrivate) import KlaviyoLocation
#endif
import os
import UIKit
import UserNotifications

// MARK: - Logger

@available(iOS 14.0, *)
extension Logger {
    static let klaviyoFlutterSDK = Logger(
        subsystem: "com.klaviyo.flutter",
        category: "KlaviyoFlutterSDK"
    )
}

public class KlaviyoFlutterSdkPlugin: NSObject, FlutterPlugin {
    // MARK: - Properties

    /// Singleton instance to allow the Host App's AppDelegate to forward events manually.
    public static let shared = KlaviyoFlutterSdkPlugin()

    private var eventSink: FlutterEventSink?

    // Cache values to handle the race condition where the value arrives
    // before Flutter has finished initializing the EventChannel.
    private var cachedToken: [String: Any]?
    private var cachedError: [String: Any]?
    private var cachedOpenedNotification: [String: Any]?
    private var cachedSilentPush: [String: Any]?
    private var cachedFormLifecycleEvents: [[String: Any]] = []

    // MARK: - Flutter Plugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Use the SHARED instance to ensure the AppDelegate accesses the same object
        let instance = KlaviyoFlutterSdkPlugin.shared

        // 1. Setup Method Channel (For Commands: initialize, setProfile, etc.)
        let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)

        // 2. Setup Event Channel (For Data Streams: tokens, opened notifications)
        let eventChannel = FlutterEventChannel(name: "klaviyo_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        // 3. Register as Application Delegate
        // This allows us to automatically intercept 'didRegisterForRemoteNotifications'
        // without requiring code in the Host App's AppDelegate.
        registrar.addApplicationDelegate(instance)
    }

    // MARK: - Method Channel Handling

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let apiKey = args["apiKey"] as? String
            else {
                let error = FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Invalid arguments for initialize",
                    details: nil
                )
                result(error)
                return
            }
            KlaviyoSDK().initialize(with: apiKey)
            result(nil)

        case "setProfile":
            guard let args = call.arguments as? [String: Any],
                  let profileData = args["profile"] as? [String: Any]
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid profile data", details: nil))
                return
            }
            let location = parseLocation(from: profileData)
            let profile = Profile(
                email: profileData["email"] as? String,
                phoneNumber: profileData["phone_number"] as? String,
                externalId: profileData["external_id"] as? String,
                firstName: profileData["first_name"] as? String,
                lastName: profileData["last_name"] as? String,
                organization: profileData["organization"] as? String,
                title: profileData["title"] as? String,
                image: profileData["image"] as? String,
                location: location,
                properties: profileData["properties"] as? [String: Any]
            )
            KlaviyoSDK().set(profile: profile)
            result(nil)

        case "setEmail":
            guard let args = call.arguments as? [String: Any],
                  let email = args["email"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid email", details: nil))
                return
            }
            KlaviyoSDK().set(email: email)
            result(nil)

        case "setPhoneNumber":
            guard let args = call.arguments as? [String: Any],
                  let phoneNumber = args["phoneNumber"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid phone number", details: nil))
                return
            }
            KlaviyoSDK().set(phoneNumber: phoneNumber)
            result(nil)

        case "setExternalId":
            guard let args = call.arguments as? [String: Any],
                  let externalId = args["externalId"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid external ID", details: nil))
                return
            }
            KlaviyoSDK().set(externalId: externalId)
            result(nil)

        case "getEmail":
            let email = KlaviyoSDK().email
            result(email)

        case "getPhoneNumber":
            let phoneNumber = KlaviyoSDK().phoneNumber
            result(phoneNumber)

        case "getExternalId":
            let externalId = KlaviyoSDK().externalId
            result(externalId)

        case "setProfileProperties":
            guard let args = call.arguments as? [String: Any],
                  let properties = args["properties"] as? [String: Any]
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid properties", details: nil))
                return
            }

            // swiftlint:disable:next identifier_name
            for (key, value) in properties {
                let profileKey = Profile.ProfileKey.from(key)
                KlaviyoSDK().set(profileAttribute: profileKey, value: value)
            }
            result(nil)

        case "trackEvent":
            guard let args = call.arguments as? [String: Any],
                  let eventData = args["event"] as? [String: Any],
                  let name = eventData["name"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid event data", details: nil))
                return
            }
            let properties = eventData["properties"] as? [String: Any] ?? [:]
            let value = eventData["value"] as? Double
            let uniqueId = eventData["unique_id"] as? String
            let event = Event(
                name: .customEvent(name),
                properties: properties,
                value: value,
                uniqueId: uniqueId
            )
            KlaviyoSDK().create(event: event)
            result(nil)

        case "registerForPushNotifications":
            // iOS requires manual APNs registration trigger
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            result(nil)

        case "setPushToken":
            guard let args = call.arguments as? [String: Any],
                  let token = args["token"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid push token", details: nil))
                return
            }

            guard !token.isEmpty else {
                if #available(iOS 14.0, *) {
                    Logger.klaviyoFlutterSDK.warning("Attempted to set empty push token")
                }
                result(FlutterError(
                    code: "INVALID_TOKEN",
                    message: "Push token cannot be empty",
                    details: nil
                ))
                return
            }

            if let tokenData = Data(hexString: token) {
                KlaviyoSDK().set(pushToken: tokenData)
            } else {
                let error = FlutterError(
                    code: "INVALID_TOKEN_FORMAT",
                    message: "Invalid token format",
                    details: nil
                )
                result(error)
                return
            }
            result(nil)

        case "getPushToken":
            let token = KlaviyoSDK().pushToken
            if let token {
                if #available(iOS 14.0, *) {
                    Logger.klaviyoFlutterSDK.info("Retrieved push token from SDK: \(token, privacy: .public)")
                }
            }
            result(token)

        case "registerForInAppForms":
            #if canImport(KlaviyoForms)
            let configuration = (call.arguments as? [String: Any])?["configuration"] as? [String: Any]
            let sessionTimeout: TimeInterval
            if let timeout = configuration?["sessionTimeoutDuration"] as? Int, timeout == -1 {
                sessionTimeout = TimeInterval.infinity
            } else if let timeout = configuration?["sessionTimeoutDuration"] as? Int {
                sessionTimeout = TimeInterval(timeout)
            } else {
                sessionTimeout = 3600 // default: 1 hour
            }

            DispatchQueue.main.async {
                KlaviyoSDK().registerForInAppForms(
                    configuration: InAppFormsConfig(sessionTimeoutDuration: sessionTimeout)
                )
                self.subscribeToFormLifecycleEvents()
            }
            result(nil)
            #else
            result(FlutterError(
                code: "FORMS_NOT_AVAILABLE",
                message: "In-App Forms requires the forms module. " +
                    "Ensure KLAVIYO_INCLUDE_FORMS is not set to 'false' in your Podfile.",
                details: nil
            ))
            #endif

        case "unregisterFromInAppForms":
            #if canImport(KlaviyoForms)
            Task { @MainActor in
                KlaviyoSDK().unregisterFormLifecycleHandler()
                KlaviyoSDK().unregisterFromInAppForms()
            }
            result(nil)
            #else
            result(FlutterError(
                code: "FORMS_NOT_AVAILABLE",
                message: "In-App Forms requires the forms module. " +
                    "Ensure KLAVIYO_INCLUDE_FORMS is not set to 'false' in your Podfile.",
                details: nil
            ))
            #endif

        case "registerGeofencing":
            #if canImport(KlaviyoLocation)
            Task { @MainActor in
                await KlaviyoSDK().registerGeofencing()
                result(nil)
            }
            #else
            result(FlutterError(
                code: "GEOFENCING_NOT_AVAILABLE",
                message: "Geofencing requires the location module. " +
                    "Set KLAVIYO_INCLUDE_LOCATION=true in your podfile.",
                details: nil
            ))
            #endif

        case "unregisterGeofencing":
            #if canImport(KlaviyoLocation)
            Task { @MainActor in
                await KlaviyoSDK().unregisterGeofencing()
                result(nil)
            }
            #else
            result(FlutterError(
                code: "GEOFENCING_NOT_AVAILABLE",
                message: "Geofencing requires the location module. " +
                    "Set KLAVIYO_INCLUDE_LOCATION=true in your podfile.",
                details: nil
            ))
            #endif

        case "getCurrentGeofences":
            #if canImport(KlaviyoLocation)
            Task { @MainActor in
                let geofences = await KlaviyoSDK().getCurrentGeofences()
                let geofencesArray = geofences.map { region -> [String: Any] in
                    [
                        "identifier": region.identifier,
                        "latitude": region.center.latitude,
                        "longitude": region.center.longitude,
                        "radius": region.radius
                    ]
                }
                result(["geofences": geofencesArray])
            }
            #else
            result(FlutterError(
                code: "GEOFENCING_NOT_AVAILABLE",
                message: "Geofencing requires the location module. " +
                    "Set KLAVIYO_INCLUDE_LOCATION=true in your podfile.",
                details: nil
            ))
            #endif

        case "resetProfile":
            KlaviyoSDK().resetProfile()
            result(nil)

        case "setBadgeCount":
            guard let args = call.arguments as? [String: Any],
                  let count = args["count"] as? Int
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Invalid badge count argument",
                        details: nil
                    )
                )
                return
            }
            KlaviyoSDK().setBadgeCount(count)
            result(nil)

        case "handleUniversalTrackingLink":
            guard let args = call.arguments as? [String: Any],
                  let urlString = args["url"] as? String,
                  let trackingUrl = URL(string: urlString)
            else {
                result(
                    FlutterError(
                        code: "INVALID_URL",
                        message: "URL cannot be null or invalid",
                        details: nil
                    )
                )
                return
            }

            let isKlaviyoLink = KlaviyoSDK().handleUniversalTrackingLink(trackingUrl)
            result(isKlaviyoLink)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - FlutterStreamHandler (Event Channel)

extension KlaviyoFlutterSdkPlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events

        // If we have cached values from early app launch, send them now.
        // This solves the race condition where values arrive before Flutter is ready.
        if let cachedToken = cachedToken {
            events(cachedToken)
            self.cachedToken = nil
        }
        if let cachedError = cachedError {
            events(cachedError)
            self.cachedError = nil
        }
        if let cachedOpenedNotification = cachedOpenedNotification {
            events(cachedOpenedNotification)
            self.cachedOpenedNotification = nil
        }
        if let cachedSilentPush = cachedSilentPush {
            events(cachedSilentPush)
            self.cachedSilentPush = nil
        }
        for cachedFormEvent in cachedFormLifecycleEvents {
            events(cachedFormEvent)
        }
        cachedFormLifecycleEvents.removeAll()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - AppDelegate Lifecycle & Notification Forwarding

extension KlaviyoFlutterSdkPlugin {
    /// Automatic Token Interception
    /// This is called automatically by Flutter because we used `registrar.addApplicationDelegate`.
    @objc
    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        if #available(iOS 14.0, *) {
            Logger.klaviyoFlutterSDK.info("APNs token received: \(tokenString, privacy: .public)")
        }

        // Pass to Klaviyo Swift SDK
        KlaviyoSDK().set(pushToken: deviceToken)

        // Create event payload
        let eventData: [String: Any] = [
            "type": "push_token_received",
            "data": ["token": tokenString]
        ]

        // Send to Flutter (or cache if Flutter is not ready)
        if let eventSink {
            eventSink(eventData)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice("Flutter not ready. Caching push token event.")
            }
            cachedToken = eventData
        }
    }

    @objc
    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        if #available(iOS 14.0, *) {
            let description = error.localizedDescription
            Logger.klaviyoFlutterSDK.warning(
                "Failed to register for remote notifications: \(description, privacy: .public)"
            )
        }

        // Create error payload
        let errorData: [String: Any] = [
            "type": "push_token_error",
            "data": ["error": error.localizedDescription]
        ]

        // Send to Flutter (or cache if Flutter is not ready)
        if let eventSink {
            eventSink(errorData)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice("Flutter not ready. Caching push token error event.")
            }
            cachedError = errorData
        }
    }

    public func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if #available(iOS 14.0, *) {
            Logger.klaviyoFlutterSDK.info("Push notification opened")
        }

        // 1. Prepare Payload
        let eventPayload: [String: Any] = [
            "type": "push_notification_opened",
            "data": userInfo
        ]

        // 2. Send to Flutter (or Cache if Flutter is asleep)
        if let eventSink = eventSink {
            eventSink(eventPayload)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice("Flutter not ready. Caching notification open event.")
            }
            cachedOpenedNotification = eventPayload
        }

        // 3. Pass to Native Klaviyo SDK
        // We pass a dummy completion handler because the Host App owns the real one.
        // No-op: We let the host app finish the system callback
        _ = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: {})
    }

    /// Manual Forwarding Helper - Silent Push
    /// This should be called from the Host App's AppDelegate
    /// in `didReceiveRemoteNotification:fetchCompletionHandler:`.
    /// Note: The host app is responsible for calling the completion handler after this method returns.
    public func handleSilentPush(userInfo: [AnyHashable: Any]) {
        if #available(iOS 14.0, *) {
            Logger.klaviyoFlutterSDK.info("Silent push received")
        }

        // Prepare payload
        let eventPayload: [String: Any] = [
            "type": "silent_push_received",
            "data": userInfo
        ]

        // Send to Flutter (or cache if Flutter is not ready)
        if let eventSink = eventSink {
            eventSink(eventPayload)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice("Flutter not ready. Caching silent push event.")
            }
            cachedSilentPush = eventPayload
        }
    }
}

// MARK: - Helpers

extension KlaviyoFlutterSdkPlugin {
    private func parseLocation(from profileData: [String: Any]) -> Profile.Location? {
        guard let locationData = profileData["location"] as? [String: Any] else { return nil }
        return Profile.Location(
            address1: locationData["address1"] as? String,
            address2: locationData["address2"] as? String,
            city: locationData["city"] as? String,
            country: locationData["country"] as? String,
            latitude: locationData["latitude"] as? Double,
            longitude: locationData["longitude"] as? Double,
            region: locationData["region"] as? String,
            zip: locationData["zip"] as? String,
            timezone: locationData["timezone"] as? String
        )
    }
}

extension Data {
    init?(hexString: String) {
        let cleanString = hexString.replacingOccurrences(of: " ", with: "")
        let length = cleanString.count
        guard length % 2 == 0 else { return nil }

        var data = Data(capacity: length / 2)
        var index = cleanString.startIndex

        for _ in 0..<(length / 2) {
            let nextIndex = cleanString.index(index, offsetBy: 2)
            let byteString = cleanString[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}

// MARK: - Form Lifecycle Events

@MainActor
extension KlaviyoFlutterSdkPlugin {
    /// Subscribe to form lifecycle events from the iOS SDK
    func subscribeToFormLifecycleEvents() {
        KlaviyoSDK().registerFormLifecycleHandler { [weak self] event, context in
            guard let self = self else { return }

            let eventPayload: [String: Any] = [
                "type": "form_lifecycle_event",
                "data": [
                    "event": event.rawValue,
                    "formId": context.formId as Any,
                    "formName": context.formName as Any
                ]
            ]

            // Send to Flutter (or cache if Flutter is not ready)
            if let eventSink = self.eventSink {
                eventSink(eventPayload)
            } else {
                print("⚠️ [Plugin] Flutter not ready. Caching form lifecycle event.")
                self.cachedFormLifecycleEvents.append(eventPayload)
            }
        }
    }
}
