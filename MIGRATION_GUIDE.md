# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v0.3.0

### Automatic push token forwarding is now the default on Android

As of v0.3.0 (which pins the native Android SDK to 4.5.0), the Klaviyo SDK forwards the Android FCM
push token to Klaviyo **automatically by default**. This formalizes behavior the bundled
`KlaviyoPushService` already performed, and is **non-breaking** — the default preserves existing
behavior.

**iOS is unchanged:** automatic forwarding remains opt-in (off by default), because iOS token
collection relies on the more invasive app-delegate method swizzling. The flag's semantics are
identical across platforms (`false` = no automatic collection); only the per-platform default
differs, for these platform-specific reasons.

**No action is required** to keep current behavior. If you prefer to own the push-token pipeline
yourself:

- **Android** — disable automatic forwarding by adding this `meta-data` to the `<application>`
  element of your `AndroidManifest.xml`, then continue setting the token yourself via
  `setPushToken(...)` or `registerForPushNotifications()`:
  ```xml
  <meta-data
      android:name="com.klaviyo.push.automatic_push_token_forwarding"
      android:value="false" />
  ```
- **iOS** — nothing to do; automatic forwarding is off unless you opt in via `Info.plist` (see the
  native [iOS README](https://github.com/klaviyo/klaviyo-swift-sdk#push-notifications)).

Because Android forwards automatically by default, calling `registerForPushNotifications()` or
setting the token manually on Android registers it through two paths — this is safe, as duplicate
tokens are deduplicated and cause no extra network request. See the
[README](https://pub.dev/packages/klaviyo_flutter_sdk) for full token-collection guidance.

> **Looking ahead:** a future **major** release may enable **both** `automatic_push_open_tracking`
> and `automatic_push_token_forwarding` by default on all platforms, bringing automatic push
> integration to parity. If that happens, apps that prefer to manage push integration manually would
> need to **opt out** of the enabled defaults (as described above for Android), rather than opt in.
> This is a non-breaking, forward-looking heads-up — nothing changes until that release, and we will
> document the exact opt-out steps in its migration guide.
