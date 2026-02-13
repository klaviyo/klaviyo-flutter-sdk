# Changelog

All notable changes to the Klaviyo Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Event Tracking**: Fixed event `uniqueId` parameter not being passed to native SDKs. The Flutter SDK now correctly forwards the `uniqueId` field from `KlaviyoEvent` to both iOS and Android native SDKs, enabling proper event deduplication when a custom unique identifier is provided.

## [1.0.0] - 2026-01-27

### Added

#### Core Features
- **Profile Management**: Complete user profile management with support for email, phone number, external ID, and custom properties
- **Event Tracking**: Track custom events and user interactions with properties and timestamps
- **Push Notifications**: Register for and handle push notifications on both iOS and Android
- **Rich Push**: Display images within push notifications (iOS requires notification service extension)
- **Badge Count**: Set and manage app icon badge count (iOS only, with notification service extension)
- **In-App Forms**: Display and manage in-app forms for lead capture with customizable configuration
- **Geofencing**: Monitor geofence regions and track location-based events (iOS and Android)

#### SDK Functionality
- Stream-based profile updates for real-time data synchronization
- Configurable log levels (none, error, warning, info, debug)
- Environment support (development, production) for push notifications
- Profile reset functionality for user logout scenarios
- Cross-platform support with native SDK wrappers

#### Platform Support
- **iOS**: Minimum version 15.0
- **Android**: Minimum API level 23 (Android 6.0)
- **Flutter**: Minimum version 3.24.0
- **Dart**: SDK >=3.0.0 <4.0.0

#### Native SDK Versions
- **iOS**: Klaviyo Swift SDK (via CocoaPods)
- **Android**: Klaviyo Android SDK modules (core, analytics, push-fcm, forms, location)

#### Documentation
- Comprehensive README with installation instructions
- API reference documentation for all public classes and methods
- Usage examples for all major features
- Platform-specific setup guides
- MIT License

### Platform-Specific Notes

#### iOS
- Requires notification service extension for badge count functionality
- Requires app group configuration for badge count
- APNs registration triggered via `registerForPushNotifications()`
- Rich push requires notification service extension implementation

#### Android
- FCM handles push token registration automatically
- Badge counts managed automatically by system
- Rich push supported without additional configuration
- Geofencing requires location permissions

[1.0.0]: https://github.com/klaviyo/klaviyo-flutter-sdk/releases/tag/v1.0.0
