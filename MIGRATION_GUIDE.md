# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v1.0.0

### iOS 15.0 is the minimum deployment target

The plugin now requires iOS 15.0 or later; 0.x declared 13.0. Builds fail if your app targets anything lower, so set the iOS deployment target to 15.0 or higher:

- **Xcode**: in `ios/Runner.xcodeproj`, set **iOS Deployment Target** to 15.0 for every target, including any notification service extension.
- **CocoaPods**: if your `ios/Podfile` has a `platform :ios` line, change it to `platform :ios, '15.0'` and run `pod install`.

iOS 15 supports the same devices as iOS 13 (iPhone 6s and newer), so this doesn't drop any devices. Flutter itself requires iOS 15 as of 3.47.

### Removed APIs

1.0 removes the APIs that 0.6.0 deprecated. Fix the 0.6.0 deprecation warnings first and your app is ready for 1.0.

| Removed | Replacement |
|---|---|
| `KlaviyoSDK().handlePushNotificationReceived(...)` | Delete the call. Push tracking is automatic. |
| `KlaviyoSDK().handlePushNotificationOpened(...)` | Delete the call. Push opens are tracked automatically and arrive on `onPushNotification` as `push_notification_opened`. |
| The `Klaviyo` class (`Klaviyo.instance`) | `KlaviyoSDK()`. [MIGRATION.md](./MIGRATION.md#quick-reference) maps every method. |
| `KlaviyoSDK().onFormEvent` | `KlaviyoSDK().onFormLifecycleEvent`, which emits typed `FormLifecycleEvent`s instead of raw maps. |
| `map.isKlaviyoNotification` | Delete the check. Klaviyo push events arrive on `KlaviyoSDK`'s streams, such as `onPushNotification` and `onPushAction`. |
| `KlaviyoSDK().dispose()` | Delete the call. If you used it to stop supplying tokens for personalized forms, call `await KlaviyoSDK().unregisterAuthTokenProvider()`. To cancel your own listeners, cancel their `StreamSubscription`s. |
| `KlaviyoNativeWrapper` (including its `dispose()` and `track()`) | `KlaviyoSDK()`. The class is internal and no longer exported. Use `createEvent(KlaviyoEvent.custom(...))` in place of `track()`. |

Before and after, for the form stream:

```dart
// Before
KlaviyoSDK().onFormEvent.listen((event) {
  if (event['type'] == 'form_lifecycle_event') { ... }
});

// After
KlaviyoSDK().onFormLifecycleEvent.listen((event) {
  switch (event) {
    case FormShown(): ...
    case FormDismissed(): ...
    case FormCtaClicked(): ...
  }
});
```

## Migrating to v0.6.0

- `KlaviyoProfile.toJson` now nests custom properties under `properties` instead of merging them into the top level, so code that reads custom keys from its output must read them from `json['properties']`; `KlaviyoProfile.fromJson` still accepts the old flat shape, but ignores unknown top-level keys when a nested `properties` map is present.
- In 0.5.0, a snake_case standard key inside `properties`, such as `first_name` or `email`, set the standard field because `toJson` flattened `properties` into the top level. It still does, on both iOS and Android, and if the matching typed field is also set, the typed field wins. Standard attribute keys are now matched in camelCase too, so `firstName` inside `properties` sets the first name as well; in 0.5.0 it was dropped. Prefer the typed `KlaviyoProfile` fields or `setProfileAttribute` for standard fields, and keep `properties` for custom keys.
- On iOS, `setProfileAttribute('email', …)` and `setProfileProperties({'email': …})` (also `phone_number` and `external_id`) used to create a custom property. They now set the identifier, as on Android, which can switch the tracked profile. Use a different key if you meant a custom property.
- `setProfile`, `setProfileAttribute` and `setProfileProperties` now ignore null values on both platforms. Android already skipped them; iOS used to send them as JSON null. Null doesn't clear a property.

## Migrating to v0.3.0

### Android's `automatic_push_token_forwarding` flag is now three-valued

The native Android SDK's `com.klaviyo.push.automatic_push_token_forwarding` manifest flag has three
states, because leaving it unset is different from setting it to `false`:

| Value | Behavior |
|---|---|
| **not set** (default) | `KlaviyoFlutterPushService` forwards a token whenever FCM delivers one — this plugin's existing automatic behavior, unchanged. This plugin initializes Klaviyo from Dart after `Application.onCreate`, so a token FCM delivers before that call is silently dropped. |
| **`true`** | Additionally fetches and registers the current token at `Klaviyo.initialize()` and on each foreground. |
| **`false`** | Disables automatic forwarding entirely. |

**No action is required on Android** — the unset default preserves this plugin's existing
automatic-forwarding behavior. Manual token management via `setPushToken(...)` continues to work
alongside it at no cost — the native SDK only sends a request when the push state actually changes.

**iOS default behavior is unchanged, and was already automatic.** This plugin registers its own
application delegate and forwards the APNs token to Klaviyo whenever iOS delivers one, unless you
explicitly opt out — see [Disabling automatic token forwarding](#disabling-automatic-token-forwarding)
below. If you haven't set `klaviyo_automatic_push_token_forwarding` in your `Info.plist`, there is
nothing to migrate on iOS.

See the [README](https://pub.dev/packages/klaviyo_flutter_sdk) for full token-collection guidance.

### Disabling automatic token forwarding

There is no way to disable automatic token forwarding from Dart, but each platform's native
`automatic_push_token_forwarding` flag now works as a real escape hatch: on iOS, this plugin itself
reads the `Info.plist` key and stands down when it's explicitly set (`true` hands forwarding to the
native SDK's own app-delegate swizzler instead; `false` disables it entirely); on Android, only an
explicit `false` disables it — `true` and unset both keep this plugin's forwarding on, since it runs
through the native SDK's own service either way. See the **Advanced** note under
[Automatic Token Forwarding](./README.md#automatic-token-forwarding) for the exact per-platform
behavior.

> **Looking ahead:** a future release may add a cross-platform way to control automatic push
> integration from Dart, and may align `automatic_push_open_tracking` and
> `automatic_push_token_forwarding` *default* behavior across platforms. If that happens, apps that
> prefer to manage push integration manually would opt out through that API rather than through
> native platform-specific configuration. This is a forward-looking heads-up — nothing changes until
> that release, and we will document the exact steps in its migration guide.
