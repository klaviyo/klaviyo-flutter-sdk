# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

You are working on the **Klaviyo Flutter SDK**, a Flutter plugin that wraps Klaviyo's native iOS (KlaviyoSwift) and Android (klaviyo-android-sdk) SDKs via platform channels. Every feature must have parity across both platforms.

## Commands

```bash
# Dependencies
flutter pub get
cd example/ios && pod install

# Build (example app — there is no standalone build for the plugin itself)
cd example && flutter build ios --no-codesign
cd example && flutter build apk

# Test
flutter test                          # all tests
flutter test test/some_test.dart      # single file
flutter test --coverage               # with lcov coverage

# Lint & format (CI runs all of these)
dart format .                         # Dart formatter (page width: 80)
flutter analyze --no-fatal-infos      # Dart static analysis
cd android && ktlint --reporter=plain # Kotlin lint
cd ios && swiftlint lint --strict     # Swift lint

# Version bump (interactive — updates pubspec.yaml, README, plist, strings.xml, CHANGELOG)
scripts/bump_version.sh <version>
```

## Architecture

```
lib/
  klaviyo_flutter_sdk.dart            # Public barrel file — all exports go here
  src/
    klaviyo_sdk.dart                  # KlaviyoSDK singleton — the public API
    services/
      klaviyo_native_wrapper.dart     # MethodChannel "klaviyo_sdk" + EventChannel "klaviyo_events"
    models/                           # Data classes (KlaviyoProfile, KlaviyoEvent, etc.)
    utils/
      buffered_broadcast_stream_controller.dart  # Buffers events before listeners attach

ios/Classes/
  KlaviyoFlutterSdkPlugin.swift       # FlutterPlugin wrapping KlaviyoSwift

android/src/main/kotlin/.../
  KlaviyoFlutterSdkPlugin.kt          # FlutterPlugin wrapping klaviyo-android-sdk
```

**Data flow:** Dart API (`KlaviyoSDK`) → platform bridge (`KlaviyoNativeWrapper`) → native plugin (Swift/Kotlin) → native Klaviyo SDK. Push/form events flow back via `EventChannel` streams.

## Native SDK Dependencies

Native SDK versions are pinned in two places — keep them in sync when bumping:
- **iOS**: `ios/klaviyo_flutter_sdk.podspec` — `KlaviyoSwift ~> X.Y.Z`
- **Android**: `android/build.gradle` — `klaviyoSdkVersion = "X.Y.Z"`

Optional features controlled by host app build properties:
- **Forms** (`klaviyoIncludeForms`): defaults to **true**
- **Geofencing** (`klaviyoIncludeLocation`): defaults to **false**, opt-in

## Gotchas

- **Trailing commas are required** (`require_trailing_commas: true`). The formatter won't add them — the analyzer will flag them.
- **No `print()`** — `avoid_print` is enforced. Use `package:logging` (see `klaviyo_sdk.dart` for the pattern).
- **Pre-commit hooks** run `dart fix --apply`, `dart format`, `flutter analyze`, `ktlint -F`, `swiftformat`, and `swiftlint` automatically. If a commit is rejected, check which hook failed.
- **Version sync**: changing `pubspec.yaml` version triggers `scripts/sync_version.sh` via pre-commit hook, which updates the iOS plist. Use `scripts/bump_version.sh` to update all version references at once.
- **Flutter version** is pinned to `3.38.7` via `.fvmrc`.
- `BufferedBroadcastStreamController` exists because native events (push tokens, notifications) can fire before Dart listeners are attached. Don't replace it with a plain `StreamController.broadcast`.
