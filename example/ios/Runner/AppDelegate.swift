import Flutter
import klaviyo_flutter_sdk
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, badge even in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "klaviyo_events", binaryMessenger: controller.binaryMessenger)
        channel.invokeMethod("push_notification_opened", arguments: response.notification.request.content.userInfo)
        completionHandler()
        
        // Forward to Klaviyo for tracking
        KlaviyoFlutterSdkPlugin.shared.userNotificationCenter(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )
    }
}
