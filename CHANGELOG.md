# Changelog

## 0.2.0 - 2026-05-04

### What's New

- **Form lifecycle events** — New `onFormLifecycleEvent` stream emits typed `FormShown`, `FormDismissed`, and `FormCtaClicked` events for in-app forms. Use Dart pattern matching for exhaustive handling. ([#75](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/75))
- **Native SDK upgrade** — Now consuming `KlaviyoSwift ~> 5.3.1` and `klaviyo-android-sdk 4.4.0`, which brings:
  - Push notification **action buttons** (up to 3 tappable buttons per Klaviyo push, configured in the Klaviyo dashboard — no integration changes required)
  - **Floating** (Android) / **Flyout** (iOS) in-app form presentation styles
  - Cross-platform form lifecycle hooks (surfaced through `onFormLifecycleEvent` above)

  See [klaviyo-android-sdk 4.4.0](https://github.com/klaviyo/klaviyo-android-sdk/releases/tag/4.4.0) and [klaviyo-swift-sdk 5.3.0](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.3.0) for full native release notes. ([#88](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/88))

### Bug Fixes

- **Android push tap events** — `onPushNotification` now correctly emits `push_notification_opened` when a user taps a Klaviyo push. Previously the event was silently dropped on Android due to a `com.klaviyo.` namespace prefix mismatch in the intent extras. ([#83](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/83))
- **Re-initialization** — `KlaviyoSDK().initialize()` no longer silently swallows subsequent calls with a different API key, enabling runtime account switching for multi-tenant apps. ([#80](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/80))
- **Flutter version compatibility** — Relaxed the `meta` dependency constraint from `^1.17.0` to `^1.15.0` so the SDK resolves cleanly against Flutter 3.24.x–3.37.x. ([#82](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/82))

### Documentation

- README updated to cover push action buttons, floating/flyout form layouts, and the typed `onFormLifecycleEvent` API. ([#90](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/90))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.3.1
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.4.0
- **Flutter**: Minimum Flutter 3.24.0, Dart 3.0.0+

[Full Changelog](https://github.com/klaviyo/klaviyo-flutter-sdk/compare/0.1.0...0.2.0)


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
