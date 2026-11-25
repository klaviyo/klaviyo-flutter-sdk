# Changelog

## 1.0.0 (Unreleased)

### Breaking

- **iOS: minimum deployment target raised from 13.0 to 15.0** — `Package.swift` and the podspec now declare iOS 15.0, matching the README. Apps must set their iOS deployment target to 15.0 or higher. iOS 15 runs on every device that runs iOS 13 (iPhone 6s and newer), so no devices are dropped. The plugin's iOS 13 code paths are gone; logging that used to be skipped below iOS 14 now always runs.

- **iOS: Swift Package Manager is the primary install path, and CocoaPods is frozen at native iOS SDK 5.7.0** — CocoaPods trunk stops accepting releases on December 2, 2026. The plugin's podspec now pins `KlaviyoSwift`, `KlaviyoForms` and `KlaviyoLocation` to `~> 5.7.0`, the planned final KlaviyoSwift release on trunk, and later releases of this plugin won't move those pins. Swift Package Manager needs Flutter 3.41+, is the default from Flutter 3.44, and follows new native iOS SDK releases. Apps on Flutter 3.27–3.40, or with Swift Package Manager turned off, still install through CocoaPods but get no native iOS fixes released after December 2, 2026, and a later 1.x may stop building with CocoaPods once it needs a newer native API. See the README's "CocoaPods (legacy)" section.
- **iOS: `KLAVIYO_INCLUDE_FORMS` and `KLAVIYO_INCLUDE_LOCATION` apply to CocoaPods only** — Swift Package Manager builds always link `KlaviyoForms` and `KlaviyoLocation`. The `FORMS_NOT_AVAILABLE` and `GEOFENCING_NOT_AVAILABLE` error messages now say so.

### Platform Support

- **iOS**: Minimum deployment target 15.0

### Documentation

- **Swift Package Manager setup for the iOS Notification Service Extension** — New README steps for adding `KlaviyoSwiftExtension` to a notification service extension with Swift Package Manager, with the frozen CocoaPods pod line for legacy apps.

## Unreleased

### New Features

- **Typed push streams.** `onPushToken` (`Stream<KlaviyoPushToken>`) emits each push token as a `KlaviyoPushToken` with the `token` string and its `type` (`KlaviyoPushTokenType.apns` on iOS, `KlaviyoPushTokenType.fcm` on Android); a registration failure arrives as a stream error carrying a `KlaviyoException` with code `PUSH_TOKEN_ERROR`. `onPushOpened` (`Stream<KlaviyoPushOpened>`) emits exactly one event for every tap on a Klaviyo push, whether on the body, an action button or a web URL push, with the tapped `button` or `webUrl` on the event. On Android, web-link taps reach `onPushOpened` and `onPushAction`. If the app is not yet subscribed, the plugin holds the tap in memory until it subscribes or the process dies. `onPushData` (`Stream<KlaviyoPushData>`) emits push data received in the foreground. `KlaviyoPushOpened` and `KlaviyoPushData` expose the push's key/value pairs as `keyValuePairs`. An open that arrives before anyone subscribes is held and delivered once, to the first `onPushOpened` subscriber; read the launch tap at any time with `getInitialPushNotification()`. See [Typed Push Streams](README.md#typed-push-streams).

### Deprecated

- The old push streams are deprecated in favor of the typed streams and will be removed in 1.0. They keep working unchanged until then.
  - `KlaviyoSDK.onPushNotification`: use `onPushToken` for tokens and token errors, `onPushOpened` for opens, and `onPushData` for silent pushes.
  - `KlaviyoSDK.onPushAction`: use `onPushOpened`, which carries the tapped button or web URL.
  - `KlaviyoPushAction`, `OpenWebUrl` and `ActionButtonTapped`: use `KlaviyoPushOpened`, with `tap` set to `KlaviyoPushTap.webUrl` (read `webUrl`) or `KlaviyoPushTap.actionButton` (read `button`).

- **`KlaviyoSDK.onFormEvent`**: use `onFormLifecycleEvent`, which emits typed `FormLifecycleEvent`s.
- **`KlaviyoSDK.handlePushNotificationReceived` and `KlaviyoSDK.handlePushNotificationOpened`**: these only logged a message. Remove the calls; push tracking is automatic.
- **`KlaviyoNativeWrapper`**: use `KlaviyoSDK`. The class becomes internal in 1.0.
- **`KlaviyoSDK.dispose()` and `KlaviyoNativeWrapper.dispose()`**: no longer needed. If you called `dispose()` to turn off personalized forms, call `await KlaviyoSDK().unregisterAuthTokenProvider()` instead. Otherwise, remove the calls.
- **`KlaviyoSDK.setLogLevel` and the `KlaviyoLogLevel` enum**: use `setLoggingEnabled(bool)`.

### Breaking Changes

- **Silent push is now push data, routed by app state**: Klaviyo push data reaches Dart in exactly one place: the new `onPushData` stream (`Stream<KlaviyoPushData>`) while the app is in the foreground, or the handler registered with the new `KlaviyoSDK.onBackgroundPushData` while it is in the background or not running. On Android a killed app now runs the handler in a headless engine instead of dropping the push. Without a handler, background push data is dropped; `silent_push_received` on `onPushNotification` still fires in the foreground. See [Push Data](README.md#push-data) and the [migration guide](MIGRATION_GUIDE.md#migrating-to-v060).
- **Push data now includes visible pushes with key/value pairs**: on both platforms, push data fires for every Klaviyo silent push and for every visible Klaviyo push that carries key/value pairs, so such a push fires twice by design (push data on arrival, `push_notification_opened` on tap). On iOS, both paths require `_k` at the top level or under `body`. On iOS the "visible content" check moved from the host `AppDelegate` into `handleSilentPush(userInfo:fetchCompletionHandler:)`, and hosts should forward every push. **Apps still using the old README snippet keep dropping visible pushes with key/value pairs until they update it.**
- **iOS: push data for visible pushes now also comes from `willPresent`** — iOS only calls `didReceiveRemoteNotification` for a visible push with key/value pairs when Background Processing is on for the message, so with it off the pairs never reached `onPushData`. The plugin now observes `userNotificationCenter(_:willPresent:withCompletionHandler:)` and emits to `onPushData` when the app isn't in the background, never calling the completion handler. A push seen by both callbacks reaches Dart once. **Upgrade step:** if your `willPresent` override doesn't call `super`, add `KlaviyoFlutterSdkPlugin.shared.handleWillPresent(notification)` to it.

### What's New

- **`ProfileProperty` constants for standard profile keys** — `ProfileProperty.firstName`, `lastName`, `organization`, `title`, `image`, `address1`, `address2`, `city`, `country`, `region`, `zip`, `latitude`, `longitude` and `timezone` hold the wire keys for Klaviyo's standard profile attributes, matching the React Native SDK's `ProfileProperty`. Pass them to `setProfileAttribute` or `setProfileProperties`. Plain string keys still work. `KlaviyoProfile` and `KlaviyoLocation` use the same constants, and no wire keys changed.
- **Event value currency** — `KlaviyoEvent` takes an optional `valueCurrency`, an ISO 4217 code (e.g. `EUR`) for the event's `value`. It is passed to the native `Event.setValueCurrency` on Android and `Event(valueCurrency:)` on iOS. Events without it are sent as before.
- **iOS: `timezone` sets the standard profile field** — `setProfileAttribute` and `setProfileProperties` with `timezone`, `timeZone` or `time_zone` now set the profile's standard timezone on iOS, as they already did on Android. It used to be stored as a custom property.
- **`KlaviyoFlutterPushService` can be subclassed (Android)** — The class is now `open`; a subclass is declared in your app manifest, calls `super.onMessageReceived`, and needs `firebase-messaging` as an app dependency.

### Bug Fixes

- **Android: FCM token rotation reaches `onPushToken`.** `KlaviyoFlutterPushService.onNewToken` delivers a `KlaviyoPushToken` with type `KlaviyoPushTokenType.fcm`. If Flutter cannot receive the token, the native plugin holds the newest rotation and delivers it once when Flutter listens. The held Dart event is in memory only; if Android kills the process before delivery, Dart gets no event. This does not change native token registration. Dart still receives rotations when `com.klaviyo.push.automatic_push_token_forwarding` is `false`. Subclasses that override `onNewToken` must call `super.onNewToken(token)`.
- **Android: push opens and action-button taps that launch the app now reach Dart.** On a cold start the tap was handled before your Dart listener subscribed, so the `push_notification_opened` event and `onPushAction`'s `ActionButtonTapped` were dropped. The plugin now holds the most recent open and the most recent action until Dart subscribes. Reopening the app from Recents doesn't re-deliver the original tap.
- **Android: web-link push taps now reach Dart through `onPushAction`.** A body tap that opens a web URL (`web_url`) emits `OpenWebUrl`. An `open_url` action button emits `ActionButtonTapped` with `action: 'open_url'`. If Flutter isn't listening yet, the plugin holds the tap in memory until your app returns and subscribes. If Android kills the process before delivery, Dart gets no event. The native SDK still tracks Opened Push. Requires Klaviyo Android SDK 4.7.0.
- **Android: the plugin builds on Kotlin Gradle Plugin 1.8** — The plugin imported `kotlin.concurrent.Volatile`, which only exists from Kotlin 1.9, so host apps on KGP 1.8 (such as the Flutter 3.27 template, which ships 1.8.22) failed in `:klaviyo_flutter_sdk:compileDebugKotlin`. It now uses `kotlin.jvm.Volatile`, and the README's minimum KGP is 1.8.0.
- **Android: camelCase profile keys now land in standard fields** — `setProfileAttribute` and `setProfileProperties` now normalize keys for standard attributes in Dart, case-insensitively and in camelCase or snake_case, before calling the native SDKs. On Android, keys such as `firstName` or `address_1` used to be saved as custom properties; they now set the standard field, matching iOS. Other keys stay custom. The README lists the supported keys.
- **`handleUniversalTrackingLink()` threw if called before `initialize()`** — It now works before `initialize()` on iOS and Android and never throws, so universal links that open the app from a cold start are tracked and resolved even if `initialize()` hasn't run yet. On Android, the plugin registers the native SDK's lifecycle callbacks first when the SDK isn't initialized yet.
- **`setProfile` dropped custom properties on iOS and Android** — `KlaviyoProfile.toJson` merged `properties` into the top level of the profile map, but both native plugins read them from a nested `properties` key, so custom properties passed to `setProfile` never reached Klaviyo. They are now sent under `properties`. `KlaviyoProfile.fromJson` reads them from the same nested key and still accepts JSON saved in the old top-level shape. Standard keys inside `properties`, such as `first_name`, `firstName`, `email` or `city`, set the standard field on both platforms, and the matching typed field wins if both are set. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **iOS: identifier keys in `setProfileAttribute` and `setProfileProperties` now set the identifier** — `email`, `phone_number` and `external_id` are now routed to `setEmail`, `setPhoneNumber` and `setExternalId` on both platforms. On iOS they used to be stored as custom properties. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **iOS: standard profile values with the wrong type were dropped** — `setProfile`, `setProfileAttribute` and `setProfileProperties` now convert number and bool values for standard text fields to strings, and number or numeric-string values for latitude and longitude to doubles, before calling the native SDKs. iOS used to drop them silently, for example `setProfileAttribute('first_name', 5)` or an integer latitude. A value that still can't be converted is dropped with a warning on both platforms. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **Null profile property values are ignored on both platforms** — `setProfile`, `setProfileAttribute` and `setProfileProperties` now drop null values in Dart. Android skipped them, while iOS forwarded them as JSON null, so the platforms disagreed. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **`setProfile` logs conflicts between typed fields and `properties`** — when a typed field such as `firstName` and the same key inside `properties` are both set, the typed value is kept and a warning names the ignored key. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **DateTime values in profile and event properties no longer make the call fail; they are sent as ISO 8601 strings.** `setProfile`, `setProfileAttribute`, `setProfileProperties` and `createEvent` convert a `DateTime`, including nested ones, to a UTC ISO 8601 string. Values the platform channel can't encode, such as `Duration`, `Uri` or custom classes, are dropped with a warning naming the key, and the rest of the call goes through. ([#178](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/178))
- **`InAppFormConfig.copyWith` dropped the infinite timeout** — copying an `InAppFormConfig.infinite()` with no arguments returned a config with the default one-hour timeout. The copy now stays infinite unless you pass a `sessionTimeoutDuration` or `isInfinite: false`.
- **`InAppFormConfig` sent negative and sub-second timeouts wrong** — a negative `sessionTimeoutDuration` such as `Duration(seconds: -1)` was sent as `-1`, which both native plugins read as "no timeout". It is now sent as 0, which is what the native SDKs use for a negative timeout. A duration under one second was truncated to 0, meaning "time out as soon as the app backgrounds"; durations now round up to the next whole second, so they are never shorter than requested.
- **iOS: `setBadgeCount` failures no longer escape as uncaught errors** — a native error from `setBadgeCount` used to reach the app's zone as an uncaught async error. It is now logged as a warning.

### New Features

- **`KlaviyoSDK().getInitialPushNotification()`** returns the push tap that launched or relaunched the app from a killed state as a `KlaviyoPushOpened`, the same type `onPushOpened` emits, or `null`. It returns the same value on every call for the life of the process, even after a stream listener received the event. Taps while the app is running never set it, and `resetProfile()` clears it. It's safe to call before `initialize()`. ([#86](https://github.com/klaviyo/klaviyo-flutter-sdk/issues/86))

### Changes

- **Cold-start push opens and actions go to the first subscriber once.** A push open or push action that arrives before anyone subscribes is buffered, one of each, newest wins, and a new open clears a buffered action. The first `onPushNotification` / `onPushAction` subscriber receives it once, then the buffer is cleared. Later subscribers don't receive it; use `getInitialPushNotification()` to read the launch tap whenever you need it. `resetProfile()` drops a buffered open and action.

### Documentation

- **iOS silent push after a force quit** — The README no longer says iOS is unaffected: a force-quit app gets no silent pushes until the user reopens it or restarts the device.
- **Using the SDK alongside `firebase_messaging` on Android** — New README section: declare `KlaviyoFlutterPushService` in your app manifest, or `firebase_messaging`'s service wins and Klaviyo pushes never display; the example app does this.

### Changed

- **`dispose()` no longer closes the SDK's event streams.** Calling it used to leave the SDK broken until the app restarted: push, form, and auth-token streams were closed for good and `initialize()` didn't reopen them. It now only unregisters the auth token provider, if one is registered.
- **`setLoggingEnabled(bool)` is now the single documented switch for Dart and native logging.** It already turned Dart-side logs on and off; with `setLogLevel` and `KlaviyoLogLevel` deprecated, it is the only logging control. The iOS plugin's own log messages now follow it as well.
- **The plugin logs less.** Push token values, full push and form event payloads, and per-call profile identifiers (email, phone number, external ID) are no longer logged. The iOS and Android token-received messages remain without the token. A few duplicate bridge messages were dropped.

## 0.5.0

### Changes

- **Updated native iOS SDK to 5.6.0** — Under-the-hood refactor that removes the vendored TCA dependency and rebuilds the request queue and flush engine. No API or default behavior changes. See [klaviyo-swift-sdk 5.6.0](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.6.0).

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.6.0
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.6.0
- **Flutter**: Minimum Flutter 3.27.0, Dart 3.0.0+

## 0.4.1

### Bug Fixes

- **In-app forms displayed incorrectly over SwiftUI sheets (iOS)** — Forms now present over full screen, so they show correctly over sheets and don't disrupt the host app's content behind them. Fixed in [klaviyo-swift-sdk 5.5.1](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.5.1). ([#161](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/161))
- **Visual artifact at the top of flyout forms on iOS 26+** — The WKWebView top edge effect is now hidden. Fixed in [klaviyo-swift-sdk 5.5.1](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.5.1). ([#161](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/161))
- **Geofencing now works in Swift Package Manager apps (iOS)** — The plugin's `Package.swift` didn't link `KlaviyoLocation`, so every geofencing method returned `GEOFENCING_NOT_AVAILABLE` in apps that resolve the plugin through Swift Package Manager, the default for Flutter 3.44+. The Swift package now always links `KlaviyoLocation`. CocoaPods apps still opt in with `KLAVIYO_INCLUDE_LOCATION`. ([#160](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/160))

### Documentation

- Geofencing setup now says iOS apps need `location` under `UIBackgroundModes` in `Info.plist`. Without it, iOS won't allow background location updates, so geofencing won't start. ([#160](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/160))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.5.1
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.6.0
- **Flutter**: Minimum Flutter 3.27.0, Dart 3.0.0+

[Full Changelog](https://github.com/klaviyo/klaviyo-flutter-sdk/compare/0.4.0...0.4.1)

## 0.4.0

### What's New

- **Personalized Forms authentication** — Register an `AuthTokenProvider` with `registerAuthTokenProvider` to supply a fresh JWT for the signed-in user. The native SDKs manage token caching, refresh, and injection into personalized in-app forms. Use `resetProfile` on logout and `unregisterAuthTokenProvider` to turn personalization off. ([#112](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/112))
- **Native SDK upgrade** — Now consuming `KlaviyoSwift ~> 5.5.0` and `klaviyo-android-sdk 4.6.0`, including native support for Personalized Forms authentication. See [iOS 5.5.0](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.5.0) and [Android 4.6.0](https://github.com/klaviyo/klaviyo-android-sdk/releases/tag/4.6.0) for the native release notes. ([#140](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/140))

### Documentation

- Adds Flutter integration guidance for backend JWT setup, provider requirements, connectivity failures, profile changes, and logout. ([#142](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/142))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.5.0
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.6.0
- **Flutter**: Minimum Flutter 3.27.0, Dart 3.0.0+

## 0.3.1 - 2026-09-04

### Bug Fixes

- **In-app forms stopped triggering after a session timeout (iOS)** — A gap in the forms webview teardown meant events fired on foreground no longer triggered forms once the session had expired. Fixed in [klaviyo-swift-sdk 5.4.1](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.4.1). ([#136](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/136))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.4.1
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.5.1
- **Flutter**: Minimum Flutter 3.27.0, Dart 3.0.0+

[Full Changelog](https://github.com/klaviyo/klaviyo-flutter-sdk/compare/0.3.0...0.3.1)

## 0.3.0 - 2026-07-28

### What's New

- **Push action events** — New `onPushAction` stream emits typed `KlaviyoPushAction` events (`OpenWebUrl`, `ActionButtonTapped`) when a user taps a Klaviyo push carrying an Open External URL (`open_url`) action or an action button. URLs are forwarded verbatim, including special schemes such as `mailto:`, `tel:`, and `sms:`. On iOS both body `open_url` taps and action-button taps surface; on Android `open_url` is handled externally by the native SDK, so only `deep_link` / `open_app` action-button taps surface.
- **Subscriptions** — New `createSubscription` method subscribes the current profile to a Klaviyo list and records its consent, with per-channel consent types for email, SMS, and WhatsApp. Use `KlaviyoSubscription.allAvailableMarketing` to request marketing consent on every channel the profile has an identifier for.
- **Swift Package Manager support**: The iOS plugin can now be consumed via Swift Package Manager in addition to CocoaPods. ([#101](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/101))
- **Android's `automatic_push_token_forwarding` flag is now three-valued**: the native manifest flag distinguishes leaving it unset (this plugin's existing automatic behavior, unchanged) from explicit `true` (additionally fetches the token at `Klaviyo.initialize()`/foreground) or `false` (disables automatic forwarding entirely). This is **non-breaking** — the unset default preserves existing behavior, and managing the token yourself via `setPushToken(...)` or `registerForPushNotifications()` continues to work alongside it. See the [Migration Guide](MIGRATION_GUIDE.md#migrating-to-v030) for details. ([#115](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/115), [#132](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/132))
- **Android automatic push-open tracking now respects the native opt-out/opt-in flag**: The plugin's automatic "Opened Push" reporting to Klaviyo now respects the native `com.klaviyo.push.automatic_push_open_tracking` manifest `meta-data` key — set it to `false` to disable it (useful if you need to withhold push data until a profile is identified), or `true` to hand reporting to the native SDK's own trampoline mechanism instead (this plugin steps aside to avoid a duplicate call). This does not affect the Dart `push_notification_opened` stream, which never reaches Klaviyo's backend. This is **non-breaking** — the default is unchanged. The `MainActivity.kt` manual `Klaviyo.handlePush()` setup step some integrations carried over is no longer necessary (and now bypasses this opt-out/opt-in if kept) — see the [README](README.md#android-setup).
- **iOS automatic push token forwarding can now be disabled**: The plugin's own APNs token forwarding now respects the native `klaviyo_automatic_push_token_forwarding` `Info.plist` key — set it to `false` to disable forwarding entirely (useful if you need to withhold push data until a profile is identified), or `true` to hand forwarding to the native SDK's own app-delegate swizzler instead. Unset behaves exactly as before. This is **non-breaking** — the default is unchanged. See the [Migration Guide](MIGRATION_GUIDE.md#disabling-automatic-token-forwarding) for details.
- **Android plugin now compiles against Flutter's `compileSdkVersion`**: The Android plugin module tracks `flutter.compileSdkVersion` instead of a hardcoded API 33, so it compiles against whichever SDK level your Flutter version vends (35 on Flutter 3.27–3.34, 36 from 3.35 on). This clears `CheckAarMetadata` failures for apps on AGP 8.13+, where transitive androidx dependencies of the native Android SDK (notably `androidx.webkit`) declare `minCompileSdk=34`. `minSdkVersion` is unchanged at 23, and the plugin still declares no `targetSdk` — your app's Play Store target level is unaffected. ([#127](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/127))
- **Minimum Flutter raised to 3.27.0**: Required by the change above — Flutter only exposes the `flutter` extension to plugin projects from 3.27.0 onward. Apps on Flutter 3.24.x–3.26.x should upgrade Flutter before adopting 0.3.0.
- **Native SDK upgrade**: Now consuming `KlaviyoSwift ~> 5.4.0` and `klaviyo-android-sdk 4.5.1`, which adds the non-web `open_url` scheme allowlist (`mailto:`, `tel:`, `sms:`) on Android. See [klaviyo-swift-sdk 5.4.0](https://github.com/klaviyo/klaviyo-swift-sdk/releases/tag/5.4.0) and [klaviyo-android-sdk 4.5.1](https://github.com/klaviyo/klaviyo-android-sdk/releases/tag/4.5.1) for full native release notes.
- **Silent push support (Android)** — Klaviyo silent pushes are now forwarded to the `onPushNotification` stream on Android as `silent_push_received`, mirroring the existing iOS `handleSilentPush` path. Events fire for every Klaviyo silent push, with or without `key_value_pairs`, and carry the full data payload, with JSON object values (`key_value_pairs`, `_k`) decoded to `Map`s so the payload has the same shape on both platforms. Delivery requires a live Flutter engine: foreground and backgrounded apps both receive events, a terminated one does not, and nothing is persisted or replayed on a later launch — matching both native SDKs. See [Silent Push](README.md#silent-push) for the terminated-state workarounds. ([#87](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/87))
- **SDK logging toggle**: New `setLoggingEnabled(bool)` / `isLoggingEnabled()` APIs silence or resume all Klaviyo SDK logging (native and Dart-side) at runtime. `setLoggingEnabled` can be called before `initialize()` to suppress startup logs. On iOS this bridges to the native `KlaviyoSDK().setLoggingEnabled(_:)` (does not affect `KlaviyoSwiftExtension`); on Android it maps to the native SDK log level (`None` when disabled, restoring the prior level when re-enabled). ([#111](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/111))

### Bug Fixes

- **Silent pushes never reached Dart on Android when the native SDK's push service won the FCM intent** — Android delivers `com.google.firebase.MESSAGING_EVENT` to exactly one service, and the native SDK registers `KlaviyoPushService` for it alongside the plugin's `KlaviyoFlutterPushService`. When the base class won, the subclass never ran: standard push, display and open tracking kept working, but silent pushes were silently dropped. The plugin now removes the base declaration from the merged manifest via `tools:node="remove"`; the subclass extends it and calls `super.onMessageReceived`, so no native behavior is lost. ([#126](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/126))
- **Silent pushes were lost when the host registered a `firebase_messaging` background handler** — `FirebaseMessaging.onBackgroundMessage()` creates a second `FlutterEngine` for the background isolate at registration time. That engine auto-registers its own plugin instance, which never subscribes to the event channel, and it claimed the process-wide reference used to deliver silent pushes — stranding them even while the app was in the foreground. Delivery now belongs to whichever engine has a live Dart listener. ([#126](https://github.com/klaviyo/klaviyo-flutter-sdk/pull/126))

### Platform Support

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.4.0
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.5.1
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
