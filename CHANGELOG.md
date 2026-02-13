# Changelog

All notable changes to the Klaviyo Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Event Tracking**: Fixed event `uniqueId` parameter not being passed to native SDKs. The Flutter SDK now correctly forwards the `uniqueId` field from `KlaviyoEvent` to both iOS and Android native SDKs, enabling proper event deduplication when a custom unique identifier is provided.

## [1.0.0] - 2026-01-27

- **iOS**: Minimum deployment target 13.0, wraps [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk) ~> 5.2.2
- **Android**: Minimum SDK version 23, wraps [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk) 4.3.1
- **Flutter**: Minimum Flutter 3.24.0, Dart 3.0.0+
