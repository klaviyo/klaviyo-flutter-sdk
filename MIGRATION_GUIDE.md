# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v0.6.0

- `KlaviyoProfile.toJson` now nests custom properties under `properties` instead of merging them into the top level, so code that reads custom keys from its output must read them from `json['properties']`; `KlaviyoProfile.fromJson` still accepts the old flat shape, but ignores unknown top-level keys when a nested `properties` map is present.
- In 0.5.0, a snake_case standard key inside `properties`, such as `first_name` or `email`, set the standard field because `toJson` flattened `properties` into the top level. It still does, on both iOS and Android, and if the matching typed field is also set, the typed field wins. Standard attribute keys are now matched in camelCase too, so `firstName` inside `properties` sets the first name as well; in 0.5.0 it was dropped. Prefer the typed `KlaviyoProfile` fields or `setProfileAttribute` for standard fields, and keep `properties` for custom keys.
- On iOS, `setProfileAttribute('email', …)` and `setProfileProperties({'email': …})` (also `phone_number` and `external_id`) used to create a custom property. They now set the identifier, as on Android, which can switch the tracked profile. Use a different key if you meant a custom property.
- `setProfile`, `setProfileAttribute` and `setProfileProperties` now ignore null values on both platforms. Android already skipped them; iOS used to send them as JSON null. Null doesn't clear a property.

### Silent push is now push data, split into `onPushData` and `onBackgroundPushData`

Push data covers Klaviyo silent pushes and visible pushes that carry key/value pairs. When the
OS delivers a qualifying push, it reaches Dart in one place, chosen by app state when it arrives: the
`onPushData` stream in the foreground, or a handler you register with
`KlaviyoSDK.onBackgroundPushData` in the background or while the app isn't running. Without a
handler, background push data is dropped.

`silent_push_received` on `onPushNotification` still fires for the same foreground pushes, so
existing listeners keep working, but it no longer fires in the background. It now also fires for
visible pushes with key/value pairs.

On iOS, visible pushes with key/value pairs can reach foreground `onPushData` through
`willPresent` without `content-available`. Background delivery on arrival requires Background
Processing on the Klaviyo message so it includes `content-available`. If iOS wakes the app, the
remote-notification callback routes the data to `onBackgroundPushData`, not `onPushData`.
A later tap emits `onPushOpened`. Both iOS data entry paths require a Klaviyo `_k` marker at the
top level or under `body`. Hand-built test payloads need it too. See [iOS delivery rules](README.md#ios).

1. Move background work into a top-level function annotated with `@pragma('vm:entry-point')` and
   register it in `main()` before `runApp`:

   ```dart
   @pragma('vm:entry-point')
   Future<void> onKlaviyoPushData(KlaviyoPushData data) async {
     // Background work. No UI.
   }

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await KlaviyoSDK.onBackgroundPushData(onKlaviyoPushData);
     runApp(const MyApp());
   }
   ```

2. **iOS**: in `AppDelegate.swift`, replace the body of
   `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` with a single call to
   `KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo:fetchCompletionHandler:)`, passing the
   system completion handler, for every push. Remove your own `aps.alert` check and your own
   `completionHandler` call: the plugin now decides which pushes are push data and calls the
   completion handler for every push. If another provider also handles this callback, branch on its
   payload before the Klaviyo call and complete those pushes yourself. See
   [iOS Setup](README.md#ios-setup). `handleSilentPush(userInfo:)` still compiles but is deprecated. It runs the same routing, so
   a push that arrives in the background is dropped when no `KlaviyoSDK.onBackgroundPushData` handler
   is registered, even if a stream listener is attached.

   If your `userNotificationCenter(_:willPresent:withCompletionHandler:)` override does not call
   `super`, add this call to that override:

   ```swift
   KlaviyoFlutterSdkPlugin.shared.handleWillPresent(notification)
   ```

   Keep your existing presentation options and completion-handler call in `willPresent`. This
   helper only observes the notification. With no override, or an override that calls `super`,
   the plugin observes `willPresent` automatically.

   Until you update the remote-notification snippet, its `aps.alert` check still filters out
   visible pushes with key/value pairs from that callback.

3. **Android**: no setup change. If you used `firebase_messaging`'s `onBackgroundMessage` only to
   catch Klaviyo silent pushes while the app was killed, you can remove it. If you keep it, see
   [Push Data > Android](README.md#android) before skipping Klaviyo pushes there: that is only safe
   once your merged manifest routes `MESSAGING_EVENT` to `KlaviyoFlutterPushService`.

### Deprecated APIs

The following APIs remain available in 0.6.0 and are scheduled for removal in 1.0. Replace calls
before upgrading to 1.0. The push-data routing changes above already apply in 0.6.0.

| Deprecated API | Replacement or action |
|---|---|
| `KlaviyoSDK.onPushNotification` | `onPushToken` for tokens/errors, `onPushOpened` for taps, `onPushData` for foreground data and `onBackgroundPushData` for background work. |
| `KlaviyoSDK.onPushAction` | `onPushOpened`, which carries action-button and web-link tap details. |
| `KlaviyoPushAction` | `KlaviyoPushOpened` from `onPushOpened`. |
| `OpenWebUrl` | `KlaviyoPushOpened` with `tap == KlaviyoPushTap.webUrl`; read `webUrl`. |
| `ActionButtonTapped` | `KlaviyoPushOpened` with `tap == KlaviyoPushTap.actionButton`; read `button`. |
| `KlaviyoSDK.onFormEvent` | `onFormLifecycleEvent`, which emits typed `FormLifecycleEvent`s. |
| `KlaviyoSDK.handlePushNotificationReceived` | Remove the Dart call; push tracking is automatic. Keep the required native forwarding. |
| `KlaviyoSDK.handlePushNotificationOpened` | Remove the Dart call; push tracking is automatic. Keep the required native forwarding. |
| `KlaviyoNativeWrapper` | Call the public `KlaviyoSDK` API; the wrapper becomes internal in 1.0. |
| `KlaviyoSDK.dispose()` | Remove it; to turn off personalized forms, explicitly `await KlaviyoSDK().unregisterAuthTokenProvider()` instead. Event streams now stay open. |
| `KlaviyoNativeWrapper.dispose()` | Remove it; it is now a no-op. |
| `KlaviyoSDK.setLogLevel(...)` | `setLoggingEnabled(bool)` for Dart/native logging on or off. |
| `KlaviyoLogLevel` | Remove the enum use when replacing `setLogLevel` with `setLoggingEnabled(bool)`. |
| `Klaviyo.instance.isKlaviyoPush(data)` (community compatibility shim) | Use `data.isKlaviyoNotification` for raw messages from another library; remove the check only if it solely gated the old `handlePush` call. |

`isKlaviyoNotification` remains supported for raw-message detection and is not deprecated. For
Klaviyo-only delivery, prefer the [typed push streams](README.md#typed-push-streams) and registered
background handler. Buffered push opens/actions reach the first subscriber of each stream once;
use `getInitialPushNotification()` to reread the launch tap. Other community-package shims are
covered in [MIGRATION.md](MIGRATION.md).

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
