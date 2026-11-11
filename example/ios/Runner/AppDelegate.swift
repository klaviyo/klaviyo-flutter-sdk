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

        // LOCAL TEST HARNESS ONLY (chunk D): simctl push does not run the NSE, so register
        // a category with the action ids used by the test payload and a dismiss action.
        let testActions = [
            UNNotificationAction(identifier: "com.klaviyo.chunkd.open_app", title: "Open App", options: [.foreground]),
            UNNotificationAction(identifier: "com.klaviyo.chunkd.link", title: "Events", options: [.foreground])
        ]
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(
                identifier: "chunkd.actions",
                actions: testActions,
                intentIdentifiers: [],
                options: .customDismissAction
            )
        ])

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
        // Per the APNs spec, title/body are nested inside alert, so this covers all visible-content cases.
        let apsPayload = userInfo["aps"] as? [String: Any]
        let hasVisibleContent = apsPayload?["alert"] != nil

        if !hasVisibleContent {
            KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo: userInfo)
        }

        completionHandler(.newData)
    }
}
