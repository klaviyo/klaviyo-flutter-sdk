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

    // Handle custom URL scheme deep links (e.g., com.klaviyo.flutterexample://push)
    override func application(
    _ application: UIApplication,
    open deepLink: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Let Flutter handle the navigation via go_router
        super.application(application, open: deepLink, options: options)
    }

    // Handle universal links (e.g., https://yourdomain.com/path)
    override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Let Flutter handle navigation via go_router
        // Flutter's redirect handler will call handleUniversalTrackingLink if needed
        // IMPORTANT: Call super first to let Flutter receive the URL
        _ = super.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )

        // Return true to indicate we handled it (prevents SDK from falling back to UIApplication.open)
        return true
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
        // 1. Forward silent push to Klaviyo plugin
        KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo: userInfo)

        // 2. You MUST call the completion handler within ~30 seconds.
        //    Failing to do so will cause iOS to throttle or stop delivering
        //    silent push notifications to your app.
        completionHandler(.newData)
    }
}
