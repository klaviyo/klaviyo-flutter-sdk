# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v0.6.0

### Background silent pushes moved to `onBackgroundSilentPush`

`silent_push_received` on `onPushNotification` now fires only while the app is in the foreground.
Silent pushes that arrive in the background, or while the app isn't running, go to a handler you
register with the experimental `KlaviyoSDK.onBackgroundSilentPush`. Each push goes to one or the
other, never both. Without a handler, background silent pushes are dropped.

1. Move background work into a top-level function annotated with `@pragma('vm:entry-point')` and
   register it in `main()` before `runApp`:

   ```dart
   @pragma('vm:entry-point')
   Future<void> onKlaviyoSilentPush(Map<String, dynamic> data) async {
     // Background work. No UI.
   }

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await KlaviyoSDK.onBackgroundSilentPush(onKlaviyoSilentPush);
     runApp(const MyApp());
   }
   ```

2. **iOS**: in `AppDelegate.swift`, replace `handleSilentPush(userInfo:)` and your own
   `completionHandler(.newData)` call with
   `handleSilentPush(userInfo:fetchCompletionHandler:)`, passing the system completion handler. The
   plugin calls it once your Dart handler finishes. See [iOS Setup](README.md#ios-setup).
   `handleSilentPush(userInfo:)` still compiles but is deprecated.

3. **Android**: if you used `firebase_messaging`'s `onBackgroundMessage` only to catch Klaviyo
   silent pushes while the app was killed, you can remove it. If you keep it, skip Klaviyo pushes
   there (they carry `_k`), since both handlers run for the same push.

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
