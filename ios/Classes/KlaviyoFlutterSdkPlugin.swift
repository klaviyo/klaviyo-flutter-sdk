import Flutter
import KlaviyoForms
import KlaviyoSwift
@_spi(KlaviyoPrivate) import KlaviyoLocation
import UIKit
import UserNotifications

public class KlaviyoFlutterSdkPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    private var eventSink: FlutterEventSink?
    private var channel: FlutterMethodChannel?
    
    // Cache for the token in case it arrives before Flutter is ready
    private var cachedToken: [String: Any]?
    
    // Stores the previous UNUserNotificationCenter delegate so we can forward forward calls to it
    private weak var previousNotificationDelegate: UNUserNotificationCenterDelegate?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: registrar.messenger())
        let instance = KlaviyoFlutterSdkPlugin()
        instance.channel = channel
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        
        // Setup Event Channel
        let eventChannel = FlutterEventChannel(
            name: "klaviyo_events", binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
        
        // Delay the delegate takeover to the next run loop.
        // This ensures we run AFTER the Host App's didFinishLaunching and other plugins.
        // It drastically reduces the chance of overwriting Firebase or other SDKs.
        DispatchQueue.main.async {
            let center = UNUserNotificationCenter.current()
            
            // Prevent double registration if register() is called multiple times
            if center.delegate === instance {
                return
            }
            
            // Capture the existing delegate (e.g., Firebase or Host App)
            instance.previousNotificationDelegate = center.delegate
            
            // Set ourselves as the new delegate
            center.delegate = instance
            
            // Debug log to help users verify integration
            if let previous = instance.previousNotificationDelegate {
                print("✅ Klaviyo Flutter SDK: Notification Delegate attached (wrapping \(type(of: previous)))")
            } else {
                print("✅ Klaviyo Flutter SDK: Notification Delegate attached (no previous delegate)")
            }
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let apiKey = args["apiKey"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Invalid arguments for initialize", details: nil
                    ))
                return
            }
            KlaviyoSDK().initialize(with: apiKey)
            result(nil)
            
        case "setProfile":
            guard let args = call.arguments as? [String: Any],
                  let profileData = args["profile"] as? [String: Any]
            else {
                result(
                    FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid profile data", details: nil))
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
                result(
                    FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid phone number", details: nil))
                return
            }
            KlaviyoSDK().set(phoneNumber: phoneNumber)
            result(nil)
            
        case "setExternalId":
            guard let args = call.arguments as? [String: Any],
                  let externalId = args["externalId"] as? String
            else {
                result(
                    FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid external ID", details: nil))
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
            let event = Event(
                name: .customEvent(name),
                properties: properties,
                value: value
            )
            KlaviyoSDK().create(event: event)
            result(nil)
            
        case "registerForPushNotifications":
            // iOS requires manual APNs registration
            // This triggers the system to request a new APNs token
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
            
            // Validate token is not empty
            guard !token.isEmpty else {
                print("⚠️ Attempted to set empty push token")
                result(FlutterError(
                    code: "INVALID_TOKEN",
                    message: "Push token cannot be empty",
                    details: nil
                ))
                return
            }
            
            // Convert hex string back to Data if needed, or handle string token directly
            if let tokenData = Data(hexString: token) {
                KlaviyoSDK().set(pushToken: tokenData)
            } else {
                // Handle as string token (for cross-platform compatibility)
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
            // Return the push token directly from the Klaviyo SDK
            let token = KlaviyoSDK().pushToken
            
            if let token = token {
                print("Retrieved push token from SDK\n:\(token)")
            } else {
                print("No push token available")
            }
            
            result(token)
            
        case "registerForInAppForms":
            // Register for in-app forms
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
            // Not directly supported in v5.0.0
            result(nil)
            
        case "setBadgeCount":
            guard let args = call.arguments as? [String: Any],
                  let count = args["count"] as? Int
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Invalid badge count argument", details: nil
                    ))
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

extension KlaviyoFlutterSdkPlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        
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

// MARK: - Flutter AppDelegate methods (APNs & Notification Callbacks)

extension KlaviyoFlutterSdkPlugin {
    // Handle successful APNs token registration
    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs Token received: \(tokenString)")
        
        // Set the token with Klaviyo Swift SDK
        KlaviyoSDK().set(pushToken: deviceToken)
        print("✅ Token set with Klaviyo SDK")
        
        // Prepare event data
        let eventData: [String: Any] = [
            "type": "push_token_received",
            "data": ["token": tokenString]
        ]
        
        // Cache it (so future listeners get it)
        self.cachedToken = eventData
        
        // Notify Flutter side via event sink
        eventSink?(eventData)
    }
    
    // Handle APNs registration failure
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
    
    // Called when user taps on a notification (app in background/terminated)
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Push notification opened with userInfo:\n\(userInfo)")
        
        // Notify Flutter side via event sink
        eventSink?([
            "type": "push_notification_opened",
            "data": userInfo
        ])
        
        // Let Klaviyo SDK handle the push open tracking
        let handled = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: completionHandler)
        
        if handled {
            print("✅ Klaviyo handled push notification open")
            // Klaviyo Swift SDK calls the completionHandler internally when it returns true
        } else {
            print("ℹ️ Non-Klaviyo push notification opened")
            
            // Forward to previous delegate if available
            if let previousDelegate = previousNotificationDelegate,
               previousDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
                previousDelegate.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
            } else {
                // If no previous delegate, WE must call completion
                completionHandler()
            }
        }
    }
    
    // Called when a notification is received while app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📱 Push notification received in foreground:\n\(userInfo)")
        
        // Forward to previous delegate if it wants to handle presentation
        if let previousDelegate = previousNotificationDelegate,
           previousDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            previousDelegate.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else {
            // Default: show the notification even when app is in foreground
            completionHandler([.banner, .sound, .badge])
        }
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
