# AI Agent Guidelines

Assume the role of an experienced Flutter/Dart SDK engineer familiar with Flutter plugins, platform channels, CocoaPods, and Gradle.
Prioritize code quality, maintainability, and reuse — search for existing implementations before adding new ones.
Keep the 3rd-party developer integration experience smooth and simple.

## Overview

This is the Flutter SDK for Klaviyo, a marketing automation platform. It is a Flutter plugin that wraps
Klaviyo's native iOS (KlaviyoSwift) and Android (klaviyo-android-sdk) SDKs via platform channels.
Every feature must have parity across both platforms. The SDK provides analytics, push notifications,
in-app messaging (forms), and geofencing.

## Common Commands

Builds go through the example app — there is no standalone build for the plugin itself.
Use `--no-codesign` for iOS: `cd example && flutter build ios --no-codesign`

### Branching

Branch format: `<initials>/<ticket-id>/<short-description>` (e.g. `ab/MAGE-123/fix-push-token`).

### Commits & Pull Requests

When committing, pushing, or opening pull requests:

- Keep commit messages concise
- Open pull requests in **draft** mode first unless otherwise directed
- Use the PR template at `.github/pull_request_template.md`
- Include a brief changelog and test plan with reproducible steps

## Architecture Overview

The plugin follows a three-layer pattern: Dart API → platform bridge → native plugin → native Klaviyo SDK.
Push/form events flow back via `EventChannel` streams.

- `lib/klaviyo_flutter_sdk.dart` — public barrel file, all exports go here
- `lib/src/klaviyo_sdk.dart` — `KlaviyoSDK` singleton, the public API entry point
- `lib/src/services/klaviyo_native_wrapper.dart` — MethodChannel `"klaviyo_sdk"` + EventChannel `"klaviyo_events"`
- `lib/src/models/` — data classes (`KlaviyoProfile`, `KlaviyoEvent`, etc.)
- `ios/Classes/KlaviyoFlutterSdkPlugin.swift` — `FlutterPlugin` wrapping KlaviyoSwift
- `android/src/main/kotlin/com/klaviyo/klaviyo_flutter_sdk/KlaviyoFlutterSdkPlugin.kt` — `FlutterPlugin` wrapping klaviyo-android-sdk

Native SDK versions are pinned in two places — keep them in sync when bumping:
- **iOS**: `ios/klaviyo_flutter_sdk.podspec` — `KlaviyoSwift ~> X.Y.Z`
- **Android**: `android/build.gradle` — `klaviyoSdkVersion = "X.Y.Z"`

Optional features controlled by host app build properties:
- **Forms** (`klaviyoIncludeForms`): defaults to **true**
- **Geofencing** (`klaviyoIncludeLocation`): defaults to **false**, opt-in

### Code Style

The project enforces code style via pre-commit hooks (`.pre-commit-config.yaml`).

Key lint rules (`analysis_options.yaml`):
- `require_trailing_commas: true` — the formatter won't add them, the analyzer will flag them
- `avoid_print: true` — use `package:logging` instead (see `klaviyo_sdk.dart` for the pattern)
- `prefer_const_constructors: true`

### Native SDK Development

To test against a local native SDK build:
- **iOS**: In `ios/klaviyo_flutter_sdk.podspec`, replace the `KlaviyoSwift ~> X.Y.Z` dependency with a local path: `s.dependency 'KlaviyoSwift', :path => '../path/to/KlaviyoSwift'`
- **Android**: In `android/build.gradle`, replace the version string with a local Maven path or use `includeBuild()` in `example/android/settings.gradle`

### Gotchas

- **Version sync**: changing `pubspec.yaml` version triggers `scripts/sync_version.sh` via pre-commit hook, which updates the iOS plist. Use `scripts/bump_version.sh` to update all version references at once.
- **Flutter version** is pinned to `3.38.7` via `.fvmrc`.
- `BufferedBroadcastStreamController` (`lib/src/utils/buffered_broadcast_stream_controller.dart`) exists because native events (push tokens, notifications) can fire before Dart listeners are attached. Don't replace it with a plain `StreamController.broadcast`.
