import Flutter
import klaviyo_flutter_sdk
import UIKit

@main
@objc
class AppDelegate: FlutterAppDelegate {
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
        // 1. Tell the SDK to track the open
        KlaviyoFlutterSdkPlugin.shared.handleNotificationResponse(response)

        // 2. Complete the system callback
        completionHandler()
    }

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Only forward to the Klaviyo plugin for pure silent pushes (no visible content).
        // Standard pushes that include content-available are handled by willPresent/didReceive.
        let apsPayload = userInfo["aps"] as? [String: Any]
        let hasVisibleContent = apsPayload?["alert"] != nil
            || apsPayload?["title"] != nil
            || apsPayload?["body"] != nil

        if !hasVisibleContent {
            KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo: userInfo)
        }

        completionHandler(.newData)
    }
}
