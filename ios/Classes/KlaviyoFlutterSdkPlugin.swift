import Flutter
import KlaviyoForms
import KlaviyoSwift
@_spi(KlaviyoPrivate) import KlaviyoLocation
import UIKit
import UserNotifications

public class KlaviyoFlutterSdkPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    
    /// Singleton instance to allow the Host App's AppDelegate to forward events manually.
    public static let shared = KlaviyoFlutterSdkPlugin()
    
    private var eventSink: FlutterEventSink?
    
    /// Cache for the token event to handle the race condition where the token arrives
    /// before Flutter has finished initializing the EventChannel.
    private var cachedToken: [String: Any]?
    
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
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for initialize", details: nil))
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
            let profile = Profile(
                email: profileData["email"] as? String,
                phoneNumber: profileData["phone_number"] as? String,
                externalId: profileData["external_id"] as? String,
                firstName: profileData["first_name"] as? String,
                lastName: profileData["last_name"] as? String,
                organization: profileData["organization"] as? String,
                title: profileData["title"] as? String,
                image: profileData["image"] as? String,
                location: nil,
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
            
        case "setProfileProperties":
            guard let args = call.arguments as? [String: Any],
                  let properties = args["properties"] as? [String: Any]
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid properties", details: nil))
                return
            }
            
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
            let event = Event(
                name: .customEvent(name),
                properties: properties,
                value: value
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
                print("⚠️ Attempted to set empty push token")
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
                print("Retrieved push token from SDK: \(token)")
            }
            result(token)
            
        case "registerForInAppForms":
            DispatchQueue.main.async {
                KlaviyoSDK().registerForInAppForms()
            }
            result(nil)
            
        case "unregisterFromInAppForms":
            Task { @MainActor in
                KlaviyoSDK().unregisterFromInAppForms()
            }
            result(nil)
            
        case "registerGeofencing":
            Task { @MainActor in
                await KlaviyoSDK().registerGeofencing()
                result(nil)
            }
            
        case "unregisterGeofencing":
            Task { @MainActor in
                await KlaviyoSDK().unregisterGeofencing()
                result(nil)
            }
            
        case "getCurrentGeofences":
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
            
        case "showForm":
            // FIXME: [CHNL-29888] implement IAF support
            let error = FlutterError(
                code: "NOT_SUPPORTED",
                message: "Direct showForm is not supported in v5.0.0; forms are shown automatically.",
                details: nil
            )
            result(error)
            
        case "hideForm":
            // FIXME: [CHNL-29888] implement IAF support
            let error = FlutterError(
                code: "NOT_SUPPORTED",
                message: "Direct hideForm is not supported in v5.0.0; forms are hidden automatically.",
                details: nil
            )
            result(error)
            
        case "resetProfile":
            KlaviyoSDK().resetProfile()
            result(nil)
            
        case "setLogLevel":
            result(nil)
            
        case "setBadgeCount":
            guard let args = call.arguments as? [String: Any],
                  let count = args["count"] as? Int
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid badge count argument", details: nil))
                return
            }
            KlaviyoSDK().setBadgeCount(count)
            result(nil)
            
        case "onPushTokenReceived":
            // Called from AppDelegate when a push token is received
            guard let args = call.arguments as? [String: Any],
                  let token = args["token"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid token data", details: nil))
                return
            }
            print("✅ Push token stored in plugin: \(token)")
            result(nil)
            
        case "onPushTokenError":
            // Called from AppDelegate when push token registration fails
            guard let args = call.arguments as? [String: Any],
                  let error = args["error"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid error data", details: nil))
                return
            }
            print("❌ Push token error received in plugin: \(error)")
            result(nil)
            
        case "onPushNotificationOpened":
            // Called from AppDelegate when a push notification is opened
            guard let args = call.arguments as? [String: Any],
                  let userInfo = args["userInfo"] as? [String: Any]
            else {
                let error = FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Invalid notification data",
                    details: nil
                )
                result(error)
                return
            }
            print("📱 Push notification opened in plugin: \(userInfo)")
            
            // Notify Flutter side via event sink if available
            if let eventSink = eventSink {
                eventSink([
                    "type": "push_notification_opened",
                    "data": userInfo
                ])
            }
            result(nil)
            
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
        self.eventSink = events
        
        // If we have a cached token from early app launch, send it now.
        // This solves the race condition where token arrives before Flutter is ready.
        if let cachedToken = cachedToken {
            events(cachedToken)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - AppDelegate Lifecycle & Notification Forwarding

extension KlaviyoFlutterSdkPlugin {
    
    // Automatic Token Interception
    // This is called automatically by Flutter because we used `registrar.addApplicationDelegate`.
    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs Token received: \(tokenString)")
        
        // Pass to Klaviyo Swift SDK
        KlaviyoSDK().set(pushToken: deviceToken)
        
        // Create event payload
        let eventData: [String: Any] = [
            "type": "push_token_received",
            "data": ["token": tokenString]
        ]
        
        // Cache it for late subscribers
        self.cachedToken = eventData
        
        // Notify Flutter side via event sink
        eventSink?(eventData)
    }
    
    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
        
        // Notify Flutter side via event sink
        eventSink?([
            "type": "push_token_error",
            "data": ["error": error.localizedDescription]
        ])
    }
    
    // Manual Forwarding Helper - "Open" Event
    // This should be called from the Host App's AppDelegate in `didReceive response`.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Push notification opened: \(userInfo)")
        
        // Notify Flutter
        eventSink?([
            "type": "push_notification_opened",
            "data": userInfo
        ])
        
        // Pass to Klaviyo Native SDK for tracking
        let handled = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: completionHandler)
        
        // If Klaviyo didn't handle the completion, we assume the host app will.
        if !handled {
            completionHandler()
        }
    }
}

// MARK: - Helpers

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
