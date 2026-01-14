import Flutter
import UIKit
import KlaviyoSwift
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Initialize Klaviyo SDK from Flutter with user-provided API key
        // KlaviyoSDK().initialize(with: "API_KEY") // Now handled from Flutter
        
        // Set up notification center delegate for push open tracking
        UNUserNotificationCenter.current().delegate = self
        
        // Request push notification permissions
        requestPushNotificationPermissions()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Request push notification permissions
    private func requestPushNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        center.requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("❌ Push notification permission error: \(error)")
                return
            }
            
            print("📱 Push notification permission granted: \(granted)")
            
            // Register for remote notifications on the main thread
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // Handle successful APNs token registration
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert token to hex string for logging and storage
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs Token received: \(tokenString)")
        
        // Set the token with Klaviyo SDK
        KlaviyoSDK().set(pushToken: deviceToken)
        print("✅ Token set with Klaviyo SDK")
        
        // Notify the Flutter plugin about the new token
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onPushTokenReceived", arguments: ["token": tokenString])
        }
    }
    
    // Handle APNs registration failure
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
        
        // Notify the Flutter plugin about the failure
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onPushTokenError", arguments: ["error": error.localizedDescription])
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
    
    // Called when user taps on a notification (app in background/terminated)
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Push notification opened with userInfo: \(userInfo)")
        
        // Notify the Flutter plugin about the push notification open
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onPushNotificationOpened", arguments: ["userInfo": userInfo])
        }
        
        // Let Klaviyo SDK handle the push open tracking
        let handled = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: completionHandler)
        
        if handled {
            print("✅ Klaviyo handled push notification open")
        } else {
            print("ℹ️ Non-Klaviyo push notification opened")
            completionHandler()
        }
    }
    
    // Called when a notification is received while app is in foreground
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📱 Push notification received in foreground: \(userInfo)")
        
        // Show the notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}
