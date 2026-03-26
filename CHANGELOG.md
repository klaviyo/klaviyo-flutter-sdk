# Changelog

## 0.1.0-alpha.1

Initial alpha release of the Klaviyo Flutter SDK.

### Features

- **SDK Initialization**: Initialize with your Klaviyo public API key
- **Profile Management**: Set and get profile identifiers (email, phone number, external ID), set full profiles with custom properties and location, and reset profiles on logout
- **Event Tracking**: Track custom events with properties and timestamps via `createEvent`
- **Push Notifications**:
  - Register for push notifications (APNs on iOS, FCM on Android)
  - Automatic push token capture and forwarding to Klaviyo
  - Push notification open tracking
  - Silent push support (iOS)
  - Rich push support (images in notifications)
  - Badge count management (iOS)
  - Stream-based push event listener (`onPushNotification`)
- **In-App Forms**: Register/unregister for in-app forms with optional configuration, with stream-based form event listener (`onFormEvent`). Forms module can be excluded to reduce SDK size.
- **Geofencing**: Register/unregister for geofence monitoring. Location module is opt-in to avoid unnecessary dependency on location services.
- **Deep Linking**: Handle Klaviyo universal tracking links with `handleUniversalTrackingLink` for click tracking and link resolution
- **Logging**: Configurable log levels (none, error, warning, info, debug)

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.2.2
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.3.1
- **Flutter**: Minimum Flutter 3.24.0, Dart 3.0.0+
