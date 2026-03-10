# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Klaviyo Flutter SDK — a Flutter plugin wrapping Klaviyo's native iOS (Swift) and Android (Kotlin) SDKs. Provides push notifications, in-app messaging, event tracking, profile management, geofencing, and deep linking.

## Common Commands

### Dependencies
```bash
flutter pub get                          # Install Flutter dependencies
cd example && flutter pub get            # Install example app dependencies
cd example/ios && pod install            # Install iOS CocoaPods
```

### Build
```bash
cd example && flutter build ios --no-codesign   # Build iOS (no signing)
cd example && flutter build apk                  # Build Android APK
```

### Test
```bash
flutter test                     # Run all tests
flutter test --coverage          # Run tests with coverage (generates coverage/lcov.info)
flutter test test/some_test.dart # Run a single test file
```

### Lint & Format
```bash
dart format .                              # Format Dart code (page width: 80)
dart format --set-exit-if-changed .        # Check formatting without modifying
flutter analyze --no-fatal-infos           # Dart/Flutter static analysis
ktlint --reporter=plain                    # Kotlin lint (run from android/)
swiftlint lint --strict                    # Swift lint (run from ios/)
```

### Version Management
```bash
scripts/bump_version.sh          # Bump SDK version
scripts/sync_version.sh          # Sync pubspec.yaml version to platform files (iOS plist)
```

## Architecture

### Plugin Structure (three-layer pattern)

1. **Dart API** (`lib/src/klaviyo_sdk.dart`) — Singleton `KlaviyoSDK` class exposing the public API. Entry point for all SDK operations.

2. **Platform Bridge** (`lib/src/services/klaviyo_native_wrapper.dart`) — Method channel (`"klaviyo_sdk"`) for commands and event channel (`"klaviyo_events"`) for push/form event streams. Uses `BufferedBroadcastStreamController` to handle events that arrive before listeners attach.

3. **Native Plugins**:
   - iOS: `ios/Classes/KlaviyoFlutterSdkPlugin.swift` — Implements `FlutterPlugin`, `FlutterStreamHandler`, `UIApplicationDelegate`. Wraps `KlaviyoSwift` SDK.
   - Android: `android/src/main/kotlin/com/klaviyo/klaviyo_flutter_sdk/KlaviyoFlutterSdkPlugin.kt` — Implements `FlutterPlugin`, `MethodCallHandler`, `ActivityAware`. Wraps Klaviyo Android SDK with Firebase messaging.

### Public API Surface
All public exports are declared in `lib/klaviyo_flutter_sdk.dart`. Models live in `lib/src/models/`.

### Optional Features (controlled via build properties)
- **In-app Forms**: `klaviyoIncludeForms` (defaults to true)
- **Geofencing**: `klaviyoIncludeLocation` (opt-in, requires additional native dependencies)

### Native SDK Versions
- iOS: `KlaviyoSwift ~> 5.2.1` (CocoaPods, podspec at `ios/klaviyo_flutter_sdk.podspec`)
- Android: `klaviyo-android-sdk:4.3.0` (Gradle, config at `android/build.gradle`)

## Code Style & Pre-commit Hooks

Pre-commit hooks (`.pre-commit-config.yaml`) run automatically on commit:
- Dart: `dart fix --apply`, `dart format`, `flutter analyze --no-fatal-infos`
- Kotlin: `ktlint -F`
- Swift: `swiftformat`, `swiftlint lint --strict`
- Version sync: `scripts/sync_version.sh` (when pubspec.yaml changes)

### Key Lint Rules
- `require_trailing_commas: true` — all multi-argument calls need trailing commas
- `avoid_print: true` — use `package:logging` instead of `print()`
- `prefer_const_constructors: true`

## Flutter Version

Pinned to **3.38.7** via `.fvmrc`. CI uses this same version.

## CI Workflows (`.github/workflows/`)

- `lint.yml` — Dart format + analyze, ktlint, swiftlint
- `test.yml` — `flutter test --coverage` with Codecov upload
- `build-ios.yml` / `build-android.yml` — Full platform builds of the example app
- `release.yml` — pub.dev publishing
- `version-check.yml` — Version consistency validation

## PR Conventions

PRs require the template at `.github/pull_request_template.md`:
- Feature parity across iOS and Android
- Tested on simulator/device for both platforms
- Categorized as Patch/Minor/Major for versioning
- Milestone label for planned version
