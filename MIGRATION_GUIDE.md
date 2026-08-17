# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v0.3.0

### Automatic push token forwarding is now the default on Android

As of v0.3.0 (which pins the native Android SDK to 4.5.0), the Klaviyo SDK forwards the Android FCM
push token to Klaviyo **automatically by default**. This formalizes behavior the bundled
`KlaviyoPushService` already performed — see the native
[Android SDK README](https://github.com/klaviyo/klaviyo-android-sdk#push-notifications) for details —
and is **non-breaking**, because the default preserves existing behavior.

**iOS default behavior is unchanged, and was already automatic.** This plugin registers its own
application delegate and forwards the APNs token to Klaviyo whenever iOS delivers one, unless you
explicitly opt out — see [Disabling automatic token forwarding](#disabling-automatic-token-forwarding)
below. If you haven't set `klaviyo_automatic_push_token_forwarding` in your `Info.plist`, there is
nothing to migrate on iOS.

**No action is required** on either platform. As of v0.3.0, token forwarding is automatic everywhere,
and manual token management via `setPushToken(...)` or `registerForPushNotifications()` continues to
work alongside it at no cost — the native SDK only sends a request when the push state actually
changes. See the [README](https://pub.dev/packages/klaviyo_flutter_sdk) for full token-collection
guidance.

### Disabling automatic token forwarding

There is no way to disable automatic token forwarding from Dart, but each platform's native
`automatic_push_token_forwarding` flag now works as a real escape hatch: on iOS, this plugin itself
reads the `Info.plist` key and stands down when it's explicitly set (`true` hands forwarding to the
native SDK's own app-delegate swizzler instead; `false` disables it entirely); on Android, the
manifest `meta-data` key already disables it, since this plugin's forwarding runs through the native
SDK's own service. See the **Advanced** note under
[Automatic Token Forwarding](./README.md#automatic-token-forwarding) for the exact per-platform
behavior.

> **Looking ahead:** a future release may add a cross-platform way to control automatic push
> integration from Dart, and may align `automatic_push_open_tracking` and
> `automatic_push_token_forwarding` *default* behavior across platforms. If that happens, apps that
> prefer to manage push integration manually would opt out through that API rather than through
> native platform-specific configuration. This is a forward-looking heads-up — nothing changes until
> that release, and we will document the exact steps in its migration guide.
