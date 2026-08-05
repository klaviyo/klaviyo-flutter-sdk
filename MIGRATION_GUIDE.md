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

**iOS is unchanged, and was already automatic.** This plugin registers its own application delegate
and forwards the APNs token to Klaviyo whenever iOS delivers one. That has always been the case and
does not depend on any native-SDK setting, so there is nothing to migrate on iOS.

**No action is required** on either platform. As of v0.3.0, token forwarding is automatic everywhere,
and manual token management via `setPushToken(...)` or `registerForPushNotifications()` continues to
work alongside it at no cost — the native SDK only sends a request when the push state actually
changes. See the [README](https://pub.dev/packages/klaviyo_flutter_sdk) for full token-collection
guidance.

### Disabling automatic token forwarding

There is currently no cross-platform way to disable automatic token forwarding from Dart. The native
SDKs' own `automatic_push_token_forwarding` flags are native-level escape hatches rather than part of
this plugin's API — notably, the iOS `Info.plist` key does **not** stop this plugin from forwarding the
token. See the **Advanced** note under
[Automatic Token Forwarding](./README.md#automatic-token-forwarding) before reaching for either.

> **Looking ahead:** a future release may add a cross-platform way to control automatic push
> integration from Dart, and may align `automatic_push_open_tracking` and
> `automatic_push_token_forwarding` behavior across platforms. If that happens, apps that prefer to
> manage push integration manually would opt out through that API rather than through native
> platform-specific configuration. This is a forward-looking heads-up — nothing changes until that
> release, and we will document the exact steps in its migration guide.
