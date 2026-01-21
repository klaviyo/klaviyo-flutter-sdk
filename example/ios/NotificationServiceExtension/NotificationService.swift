//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Andrew Balmer on 1/20/26.
//

import KlaviyoSwiftExtension
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var request: UNNotificationRequest!
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        // Track any custom key-value pairs sent in the push so the Test App can display them
        storeCustomValues(from: request.content.userInfo)
        
        self.request = request
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Let Klaviyo handle the notification content modification
            // This handles:
            // - Rich media (images) attached to push notifications
            // - Badge count management (increment/set based on payload)
            KlaviyoExtensionSDK.handleNotificationServiceDidReceivedRequest(
                request: self.request,
                bestAttemptContent: bestAttemptContent,
                contentHandler: contentHandler
            )
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent
        {
            KlaviyoExtensionSDK.handleNotificationServiceExtensionTimeWillExpireRequest(
                request: self.request,
                bestAttemptContent: bestAttemptContent,
                contentHandler: contentHandler
            )
        }
    }
    
    private func storeCustomValues(from userInfo: [AnyHashable: Any]) {
        let appGroup = "group.com.klaviyo.FlutterExample"
        
        guard let userDefaults = UserDefaults(suiteName: appGroup) else { return }
        if let kvPairs = userInfo["key_value_pairs"] as? [String: Any] {
            var result = ""
            for (key, value) in kvPairs {
                result += "Key: \(key), Value: \(value)\n"
            }
            userDefaults.set(result, forKey: "key_value_pairs")
        }
    }
}
