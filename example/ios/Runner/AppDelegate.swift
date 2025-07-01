import Flutter
import UIKit
import KlaviyoSwift

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize Klaviyo SDK (optional - can also be done from Flutter)
    KlaviyoSDK().initialize(with: "Xr5bFG")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
