import Flutter
import os
import UIKit

/// A background push waiting for the Dart handler, with the system completion handler
/// that must be called exactly once.
final class BackgroundPushDataDelivery {
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
            withName: "KlaviyoPushData"
        ) { [weak self] in
            self?.finish(.failed)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
            guard let self, !self.isFinished else { return }
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.warning("Background push data handler timed out")
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

// MARK: - Background Push Data

extension KlaviyoFlutterSdkPlugin {
    /// Delivers a silent push to Dart, routed by app state. Call it from the Host App's AppDelegate
    /// in `didReceiveRemoteNotification:fetchCompletionHandler:` and pass the system completion
    /// handler.
    ///
    /// - Foreground or inactive: emitted on `KlaviyoSDK.onPushData`, and on `onPushNotification` as
    ///   `silent_push_received`; `completionHandler` is called right away.
    /// - Background, including a relaunch from killed: passed to the Dart handler registered with
    ///   `KlaviyoSDK.onBackgroundPushData`. `completionHandler` is called when the handler finishes,
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
            emitPushDataToStream(userInfo: userInfo)
            completionHandler(.newData)
            return
        }

        if #available(iOS 14.0, *) {
            Logger.klaviyoFlutterSDK.info("Push data received in background")
        }

        let delivery = BackgroundPushDataDelivery(userInfo: userInfo, completionHandler: completionHandler)
        delivery.start()

        if isBackgroundHandlerRegistered {
            invokeBackgroundHandler(delivery)
        } else if hasStreamListener {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice(
                    "No background push data handler registered. Dropping push data."
                )
            }
            delivery.finish(.noData)
        } else {
            if #available(iOS 14.0, *) {
                Logger.klaviyoFlutterSDK.notice(
                    "Background push data handler not registered yet. Holding push data."
                )
            }
            pendingBackgroundPushData?.finish(.noData)
            pendingBackgroundPushData = delivery
        }
    }

    /// Marks the Dart background handler as registered and delivers a held push, if any.
    func registerBackgroundPushDataHandler() {
        isBackgroundHandlerRegistered = true
        if let pending = pendingBackgroundPushData {
            pendingBackgroundPushData = nil
            if !pending.isFinished {
                invokeBackgroundHandler(pending)
            }
        }
    }

    private func invokeBackgroundHandler(_ delivery: BackgroundPushDataDelivery) {
        guard let backgroundChannel else {
            delivery.finish(.failed)
            return
        }
        backgroundChannel.invokeMethod(
            "handleBackgroundPushData",
            arguments: ["data": delivery.userInfo]
        ) { result in
            if let error = result as? FlutterError {
                if #available(iOS 14.0, *) {
                    Logger.klaviyoFlutterSDK.error(
                        "Background push data handler failed: \(error.code, privacy: .public)"
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
