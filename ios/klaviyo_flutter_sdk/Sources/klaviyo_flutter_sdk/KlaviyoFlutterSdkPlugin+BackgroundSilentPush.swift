import Flutter
import os
import UIKit

/// A background silent push waiting for the Dart handler, with the system completion handler
/// that must be called exactly once.
final class BackgroundSilentPushDelivery {
    let userInfo: [AnyHashable: Any]
    private var completionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    static let timeout: TimeInterval = 25

    init(
        userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self.userInfo = userInfo
        self.completionHandler = completionHandler
    }

    var isFinished: Bool { completionHandler == nil }

    /// Starts a background task and schedules `finish(.failed)` after `timeout` seconds.
    func start() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "KlaviyoSilentPush"
        ) { [weak self] in
            self?.finish(.failed)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
            guard let self, !self.isFinished else { return }
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.warning("Background silent push handler timed out")
            }
            self.finish(.failed)
        }
    }

    /// Calls the completion handler and ends the background task. Later calls do nothing.
    func finish(_ result: UIBackgroundFetchResult) {
        guard let completionHandler else { return }
        self.completionHandler = nil
        completionHandler(result)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - Background Silent Push

extension KlaviyoFlutterSdkPlugin {
    /// Routes a silent push by app state. Call it from the Host App's AppDelegate in
    /// `didReceiveRemoteNotification:fetchCompletionHandler:` and pass the system completion handler.
    ///
    /// - Foreground or inactive: emitted on the `onPushNotification` stream as
    ///   `silent_push_received`; `completionHandler` is called right away.
    /// - Background, including a relaunch from killed: passed to the Dart handler registered with
    ///   `KlaviyoSDK.onBackgroundSilentPush`. `completionHandler` is called when the handler finishes,
    ///   or after 25 seconds. If Dart isn't running yet, the most recent push waits in memory for
    ///   registration until that timeout. If Dart is running with no handler, the push is dropped.
    ///
    /// The plugin owns `completionHandler`; the host must not call it.
    public func handleSilentPush(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.handleSilentPush(userInfo: userInfo, fetchCompletionHandler: completionHandler)
            }
            return
        }

        if UIApplication.shared.applicationState != .background {
            emitSilentPushToStream(userInfo: userInfo)
            completionHandler(.newData)
            return
        }

        if #available(iOS 14.0, *) {
            Logger.klaviyoFlutterSDK.info("Silent push received in background")
        }

        let delivery = BackgroundSilentPushDelivery(userInfo: userInfo, completionHandler: completionHandler)
        delivery.start()

        if isBackgroundHandlerRegistered {
            invokeBackgroundHandler(delivery)
        } else if hasStreamListener {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice(
                    "No background silent push handler registered. Dropping silent push."
                )
            }
            delivery.finish(.noData)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice(
                    "Background silent push handler not registered yet. Holding silent push."
                )
            }
            pendingBackgroundSilentPush?.finish(.noData)
            pendingBackgroundSilentPush = delivery
        }
    }

    /// Marks the Dart background handler as registered and delivers a held push, if any.
    func registerBackgroundSilentPushHandler() {
        isBackgroundHandlerRegistered = true
        if let pending = pendingBackgroundSilentPush {
            pendingBackgroundSilentPush = nil
            if !pending.isFinished {
                invokeBackgroundHandler(pending)
            }
        }
    }

    private func invokeBackgroundHandler(_ delivery: BackgroundSilentPushDelivery) {
        guard let backgroundChannel else {
            delivery.finish(.failed)
            return
        }
        backgroundChannel.invokeMethod(
            "handleBackgroundSilentPush",
            arguments: ["data": delivery.userInfo]
        ) { result in
            if let error = result as? FlutterError {
                if #available(iOS 14.0, *) {
                    Logger.klaviyoFlutterSDK.error(
                        "Background silent push handler failed: \(error.code, privacy: .public)"
                    )
                }
                delivery.finish(.failed)
            } else if (result as? NSObject) === FlutterMethodNotImplemented {
                delivery.finish(.failed)
            } else {
                delivery.finish(.newData)
            }
        }
    }
}
