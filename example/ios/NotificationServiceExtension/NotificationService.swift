//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Andrew Balmer on 1/20/26.
//

import KlaviyoSwiftExtension
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Let Klaviyo handle the notification content modification
            // This handles:
            // - Rich media (images) attached to push notifications
            // - Badge count management (increment/set based on payload)
            KlaviyoExtensionSDK.handleNotificationServiceDidReceivedRequest(
                request: request,
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
                request: UNNotificationRequest(
                    identifier: bestAttemptContent.threadIdentifier,
                    content: bestAttemptContent,
                    trigger: nil
                ),
                bestAttemptContent: bestAttemptContent,
                contentHandler: contentHandler
            )
        }
    }
}
