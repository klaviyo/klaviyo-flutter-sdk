# Flutter SDK Migration Guide

This guide outlines how developers can migrate from older versions of the
`klaviyo_flutter_sdk` package to newer ones.

> Migrating from the community [`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter)
> package to the official SDK? See [MIGRATION.md](./MIGRATION.md) instead.

## Migrating to v0.3.0

### Android's `automatic_push_token_forwarding` flag is now three-valued

The native Android SDK's `com.klaviyo.push.automatic_push_token_forwarding` manifest flag has three
states, because leaving it unset is different from setting it to `false`:

| Value | Behavior |
|---|---|
| **not set** (default) | `KlaviyoFlutterPushService` forwards a token whenever FCM delivers one — this plugin's existing automatic behavior, unchanged. |
| **`true`** | Additionally fetches and registers the current token at `Klaviyo.initialize()` and on each foreground. |
| **`false`** | Disables automatic forwarding entirely. |

**No action is required** — the unset default preserves this plugin's existing automatic-forwarding
behavior on Android. Manual token management via `setPushToken(...)` continues to work alongside it
at no cost — the native SDK only sends a request when the push state actually changes. See the
[README](https://pub.dev/packages/klaviyo_flutter_sdk) for full token-collection guidance.

### Disabling automatic token forwarding

There is currently no cross-platform way to disable automatic token forwarding from Dart. The native
SDKs' own `automatic_push_token_forwarding` flags are native-level escape hatches rather than part of
this plugin's API — notably, the iOS `Info.plist` key does **not** stop this plugin from forwarding
the token, and on Android only an explicit `false` is a complete opt-out (`true` and unset both keep
forwarding on). See the **Advanced** note under
[Automatic Token Forwarding](./README.md#automatic-token-forwarding) before reaching for either.

> **Looking ahead:** a future release may add a cross-platform way to control automatic push
> integration from Dart, and may align `automatic_push_open_tracking` and
> `automatic_push_token_forwarding` behavior across platforms. If that happens, apps that prefer to
> manage push integration manually would opt out through that API rather than through native
> platform-specific configuration. This is a forward-looking heads-up — nothing changes until that
> release, and we will document the exact steps in its migration guide.
