# Klaviyo Flutter SDK - Native Wrapper Implementation

## Overview

This document summarizes the conversion of the Klaviyo Flutter SDK from a pure Flutter implementation to a native wrapper around the official Klaviyo native SDKs.

## Architecture

The SDK now follows a native wrapper pattern:

```
Flutter App
    ↓
Klaviyo Flutter SDK (Dart)
    ↓
Platform Channels
    ↓
Native SDKs:
- iOS: Klaviyo Swift SDK
- Android: Klaviyo Android SDK
```

## Key Changes Made

### 1. Main SDK (`lib/src/klaviyo_sdk.dart`)
- **Before**: Pure Flutter implementation with HTTP calls, Firebase integration, and custom services
- **After**: Native wrapper that delegates all operations to native SDKs via platform channels
- **Benefits**: 
  - Leverages native SDK features and optimizations
  - Better performance and reliability
  - Automatic platform-specific handling

### 2. Native Wrapper Service (`lib/src/services/klaviyo_native_wrapper.dart`)
- **New**: Platform channel implementation for communicating with native SDKs
- **Features**:
  - Method channel for synchronous operations
  - Event channel for real-time updates
  - Error handling and type conversion
  - Stream-based event handling

### 3. Platform-Specific Implementations

#### Android (`android/`)
- **Plugin Class**: `KlaviyoFlutterSdkPlugin.kt`
- **Dependencies**: Klaviyo Android SDK via Maven
- **Features**: Full integration with native Android SDK methods
- **Permissions**: Internet, wake lock, vibrate, boot completed

#### iOS (`ios/`)
- **Plugin Class**: `KlaviyoFlutterSdkPlugin.swift`
- **Dependencies**: Klaviyo Swift SDK via CocoaPods
- **Features**: Full integration with native iOS SDK methods
- **Permissions**: User notification usage description

### 4. Dependencies Cleanup
- **Removed**: HTTP, Firebase, device info, connectivity, webview, and other pure Flutter dependencies
- **Kept**: `shared_preferences` for local storage
- **Result**: Lighter package with fewer dependencies

### 5. Configuration Updates
- **pubspec.yaml**: Updated to reflect plugin structure
- **Android build.gradle**: Added native SDK dependency
- **iOS podspec**: Added Swift SDK dependency

## API Compatibility

The public API remains largely the same, ensuring backward compatibility:

### Core Methods
```dart
// Initialization
await klaviyo.initialize(apiKey: 'key', logLevel: debug, environment: development);

// Profile Management
await klaviyo.setProfile(profile);
await klaviyo.setEmail(email);
await klaviyo.setPhoneNumber(phone);
await klaviyo.setExternalId(id);
await klaviyo.setProfileProperties(props);

// Event Tracking
await klaviyo.track('Event Name', properties);
await klaviyo.trackEvent(event);

// Push Notifications
await klaviyo.registerForPushNotifications();
await klaviyo.setPushToken(token);

// In-App Forms
await klaviyo.registerForInAppForms(config);
await klaviyo.showForm(formId);
await klaviyo.hideForm(formId);

// Profile Reset
await klaviyo.resetProfile();
```

### Models
- `KlaviyoProfile` - User profile data
- `KlaviyoEvent` - Event tracking data
- `KlaviyoLocation` - Geographic location
- `InAppFormConfig` - Form configuration
- `PushTokenInfo` - Push token information

### Enums
- `KlaviyoLogLevel` - Logging levels
- `PushEnvironment` - Environment types

## Benefits of Native Wrapper Approach

### 1. **Performance**
- Native SDKs are optimized for their respective platforms
- Reduced overhead from HTTP calls and custom implementations
- Better memory management and battery efficiency

### 2. **Reliability**
- Native SDKs handle platform-specific edge cases
- Automatic retry logic and error handling
- Better network resilience

### 3. **Feature Completeness**
- Access to all native SDK features
- Automatic platform-specific optimizations
- Real-time updates and event handling

### 4. **Maintenance**
- Reduced codebase size and complexity
- Automatic updates when native SDKs are updated
- Less platform-specific code to maintain

### 5. **Consistency**
- Same behavior across platforms
- Consistent with other Klaviyo SDK implementations
- Better integration with Klaviyo's ecosystem

## Setup Requirements

### For Developers
1. **iOS**: Add Klaviyo Swift SDK to Podfile and run `pod install`
2. **Android**: Add Klaviyo Android SDK to build.gradle
3. **Permissions**: Configure platform-specific permissions
4. **API Key**: Use valid Klaviyo public API key

### For End Users
- No additional setup required
- Automatic platform detection and configuration
- Seamless integration with existing Flutter apps

## Migration Guide

### From Pure Flutter Implementation
1. **Update dependencies**: Remove Firebase and other heavy dependencies
2. **Platform setup**: Add native SDK dependencies
3. **Permissions**: Configure platform-specific permissions
4. **API calls**: No changes needed - API remains the same
5. **Testing**: Test on both platforms to ensure native integration works

### Breaking Changes
- **None**: Public API remains fully compatible
- **Internal**: Implementation details changed but interface preserved

## Testing

### Example App
- Updated example app demonstrates all features
- Platform-specific testing on iOS and Android
- Error handling and edge case testing

### Analysis
- Flutter analyze passes with no issues
- Example app compiles successfully
- All dependencies resolved correctly

## Future Enhancements

### Potential Improvements
1. **Advanced Configuration**: More granular native SDK configuration options
2. **Custom Events**: Enhanced event tracking capabilities
3. **Analytics**: Better integration with Flutter analytics
4. **Testing**: Comprehensive unit and integration tests
5. **Documentation**: Enhanced API documentation and examples

### Native SDK Updates
- Automatic benefit from native SDK improvements
- New features available as soon as native SDKs support them
- Reduced maintenance burden

## Conclusion

The conversion to a native wrapper approach provides significant benefits:

- **Better Performance**: Leverages native optimizations
- **Enhanced Reliability**: Uses battle-tested native SDKs
- **Reduced Maintenance**: Less custom code to maintain
- **Feature Completeness**: Access to all native SDK features
- **Future-Proof**: Automatic updates from native SDK improvements

The implementation maintains full API compatibility while providing a more robust and efficient solution for Flutter developers integrating with Klaviyo. 