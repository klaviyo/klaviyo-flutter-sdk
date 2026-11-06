/// Extensions on [Map] for Klaviyo push notification detection.
extension KlaviyoNotificationMap on Map<String, dynamic> {
  /// Whether this map represents a Klaviyo push notification.
  ///
  /// Works with:
  /// - **Raw iOS APNs payloads** (checks for `_k` inside the `body` dictionary)
  /// - **Raw Android FCM payloads** (checks for `_k`)
  @Deprecated(
    "No longer needed; Klaviyo push events arrive on KlaviyoSDK's streams. "
    'Will be removed in 1.0.',
  )
  bool get isKlaviyoNotification =>
      (this['body'] is Map && (this['body'] as Map).containsKey('_k')) ||
      containsKey('_k');
}
