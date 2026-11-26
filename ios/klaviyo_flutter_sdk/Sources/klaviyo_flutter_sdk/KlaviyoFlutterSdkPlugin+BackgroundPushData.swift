import Flutter
import os
import UIKit
import UserNotifications

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

    var isFinished: Bool {
        completionHandler == nil
    }

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
    /// Delivers Klaviyo push data to Dart, routed by app state. Call it from the Host App's AppDelegate in
    /// `didReceiveRemoteNotification:fetchCompletionHandler:` for every push, and pass the system
    /// completion handler.
    ///
    /// Push data requires a Klaviyo `_k` marker, at the top level or under `body`, and either no
    /// `aps.alert` (silent) or `key_value_pairs`. Other pushes complete with `.noData` without
    /// reaching Dart.
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

        guard Self.isPushData(userInfo) else {
            completionHandler(.noData)
            return
        }

        if UIApplication.shared.applicationState != .background {
            emitForegroundPushData(userInfo: userInfo)
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

    /// Delivers the key/value pairs of a Klaviyo push that arrives while the app is not in the
    /// background, from `userNotificationCenter(_:willPresent:withCompletionHandler:)`. It only
    /// observes: it never calls the completion handler and never changes how the notification is
    /// presented. Hosts whose `willPresent` override doesn't call `super` call this themselves.
    ///
    /// A push that also reaches `handleSilentPush(userInfo:fetchCompletionHandler:)` reaches Dart once.
    public func handleWillPresent(_ notification: UNNotification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.handleWillPresent(notification) }
            return
        }

        let userInfo = notification.request.content.userInfo
        guard Self.isWillPresentPushData(userInfo),
              UIApplication.shared.applicationState != .background
        else { return }

        emitForegroundPushData(userInfo: userInfo, requestIdentifier: notification.request.identifier)
    }

    /// Receives `willPresent` automatically through `addApplicationDelegate`. It does not call the
    /// completion handler; the host's own `UNUserNotificationCenterDelegate` owns it.
    @objc
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleWillPresent(notification)
    }

    /// Emits push data to the stream unless the same push was already emitted in the last
    /// `recentPushDataWindow` seconds. Main thread only.
    func emitForegroundPushData(userInfo: [AnyHashable: Any], requestIdentifier: String? = nil) {
        if let dedupeKey = Self.pushDataDedupeKey(userInfo: userInfo, requestIdentifier: requestIdentifier) {
            let current = Date()
            recentPushDataKeys.removeAll { current.timeIntervalSince($0.date) > Self.recentPushDataWindow }
            if recentPushDataKeys.contains(where: { $0.key == dedupeKey }) {
                return
            }
            recentPushDataKeys.append((key: dedupeKey, date: current))
            if recentPushDataKeys.count > Self.recentPushDataLimit {
                recentPushDataKeys.removeFirst(recentPushDataKeys.count - Self.recentPushDataLimit)
            }
        }
        emitPushDataToStream(userInfo: userInfo)
    }

    /// The Klaviyo tracking marker (`_k`, top level or under `body`) identifies a push across
    /// `willPresent` and `didReceiveRemoteNotification`. Without one, the notification request
    /// identifier is used when the caller has it. Returns nil when neither exists: no dedupe.
    static func pushDataDedupeKey(userInfo: [AnyHashable: Any], requestIdentifier: String?) -> String? {
        if let tracking = klaviyoPushMarker(userInfo) {
            if JSONSerialization.isValidJSONObject(tracking),
               let data = try? JSONSerialization.data(withJSONObject: tracking, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                return "k:\(text)"
            }
            return "k:\(tracking)"
        }
        if let requestIdentifier {
            return "id:\(requestIdentifier)"
        }
        return nil
    }

    private static func klaviyoPushMarker(_ userInfo: [AnyHashable: Any]) -> Any? {
        userInfo["_k"] ?? (userInfo["body"] as? [String: Any])?["_k"]
    }

    /// True for a Klaviyo push with no `aps.alert`, or one carrying `key_value_pairs`.
    static func isPushData(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard klaviyoPushMarker(userInfo) != nil else { return false }
        let apsPayload = userInfo["aps"] as? [String: Any]
        return apsPayload?["alert"] == nil || userInfo["key_value_pairs"] != nil
    }

    /// True for a Klaviyo push carrying `key_value_pairs` in `willPresent`.
    static func isWillPresentPushData(_ userInfo: [AnyHashable: Any]) -> Bool {
        klaviyoPushMarker(userInfo) != nil && userInfo["key_value_pairs"] != nil
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
