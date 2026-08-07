# Changelog

## 0.3.0 - 2026-07-28

### What's New

- **Push action events** — New `onPushAction` stream emits typed `KlaviyoPushAction` events (`OpenWebUrl`, `ActionButtonTapped`) when a user taps a Klaviyo push carrying an Open External URL (`open_url`) action or an action button. URLs are forwarded verbatim, including special schemes such as `mailto:`, `tel:`, and `sms:`. On iOS both body `open_url` taps and action-button taps surface; on Android `open_url` is handled externally by the native SDK, so only `deep_link` / `open_app` action-button taps surface.
- **SDK logging toggle**: New `setLoggingEnabled(bool)` / `isLoggingEnabled()` APIs silence or resume all Klaviyo SDK logging (native and Dart-side) at runtime. `setLoggingEnabled` can be called before `initialize()` to suppress startup logs. On iOS this bridges to the native `KlaviyoSDK().setLoggingEnabled(_:)` (does not affect `KlaviyoSwiftExtension`); on Android it maps to the native SDK log level (`None` when disabled, restoring the prior level when re-enabled). ([#111](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/111))
- **Swift Package Manager support**: The iOS plugin can now be consumed via Swift Package Manager in addition to CocoaPods. ([#101](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/101))
- **Automatic push token forwarding is now the default on Android**: The native Android SDK forwards the FCM push token to Klaviyo automatically, formalizing behavior the bundled `KlaviyoPushService` already performed. This is **non-breaking** — the default preserves existing behavior, and managing the token yourself via `setPushToken(...)` or `registerForPushNotifications()` continues to work alongside it. iOS is unchanged and was already automatic, since this plugin registers its own application delegate. See the [Migration Guide](MIGRATION_GUIDE.md#migrating-to-v030) for details and the native-level opt-outs. ([#115](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/115))
- **Minimum Flutter raised to 3.27.0**: The Android plugin reads `flutter.compileSdkVersion`, which only exists in Flutter 3.27.0+. Apps on Flutter 3.24.x–3.26.x should upgrade Flutter before adopting 0.3.0.
- **Native SDK upgrade**: Now consuming `KlaviyoSwift ~> 5.4.0` and `klaviyo-android-sdk 4.5.0`, which adds the non-web `open_url` scheme allowlist (`mailto:`, `tel:`, `sms:`) on Android. See [klaviyo-swift-sdk 5.4.0](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.4.0) and [klaviyo-android-sdk 4.5.0](https://github.com/klaviyo/klaviyo-android-sdk/releases/tag/4.5.0) for full native release notes.
- **Silent push support (Android)** — Klaviyo silent pushes are now forwarded to the `onPushNotification` stream on Android as `silent_push_received`, mirroring the existing iOS `handleSilentPush` path. ([#87](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/87))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.4.0
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.5.0
- **Flutter**: Minimum Flutter 3.27.0, Dart 3.0.0+

[Full Changelog](https://github.com/klaviyo/klaviyo-flutter-sdk/compare/0.2.0...0.3.0)

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
