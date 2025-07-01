# Push Token Handling Without Firebase

This guide explains how to handle push tokens in the Klaviyo Flutter SDK without using Firebase dependencies.

## Overview

With Firebase removed from the SDK, push token handling is now done using native platform methods. This approach:

- ✅ Eliminates Firebase modular header conflicts
- ✅ Reduces dependencies and app size
- ✅ Uses platform-native push notification systems directly
- ✅ Works with both APNs (iOS) and FCM (Android) through native SDKs

## Platform-Specific Implementation

### iOS (APNs)

On iOS, push tokens are handled through the native Apple Push Notification service (APNs):

#### 1. Register for Push Notifications

```dart
// Request permission and register for push notifications
await _klaviyo.registerForPushNotifications();
```

This method:
- Calls `UIApplication.shared.registerForRemoteNotifications()` on iOS
- Requests notification permissions through the permission_handler package
- The iOS system will generate an APNs token

#### 2. Handle Push Token in Native Code

You need to implement the push token handling in your iOS `AppDelegate`:

```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import KlaviyoSwift

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize Klaviyo (if not done from Flutter)
    // KlaviyoSDK().initialize(with: "YOUR_API_KEY")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle successful APNs token registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Set the token directly with Klaviyo
    KlaviyoSDK().set(pushToken: deviceToken)
  }
  
  // Handle APNs registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")
  }
}
```

### Android (FCM)

On Android, the native Klaviyo SDK handles FCM integration:

#### 1. Register for Push Notifications

```dart
// Register for push notifications
await _klaviyo.registerForPushNotifications();
```

This method calls `Klaviyo.registerForPushNotifications()` on the Android side, which:
- Handles FCM token registration automatically
- Manages notification permissions
- Sets up the push token with Klaviyo

#### 2. Native Android Setup

The Android implementation automatically handles FCM tokens through the native SDK. Make sure your `android/app/build.gradle` includes:

```gradle
dependencies {
    implementation "com.github.klaviyo.klaviyo-android-sdk:analytics:4.0.0"
    implementation "com.github.klaviyo.klaviyo-android-sdk:push-fcm:4.0.0"
}
```

## Flutter SDK Methods

### registerForPushNotifications()

Registers for push notifications on both platforms:

```dart
try {
  await _klaviyo.registerForPushNotifications();
  print('Successfully registered for push notifications');
} catch (e) {
  print('Failed to register: $e');
}
```

### setPushToken(String token)

Manually set a push token (if you obtain it through other means):

```dart
try {
  await _klaviyo.setPushToken('your_push_token_here');
  print('Push token set successfully');
} catch (e) {
  print('Failed to set token: $e');
}
```

### getPushToken()

Get push token information (returns metadata, not the actual token):

```dart
try {
  final tokenInfo = await _klaviyo.getPushToken();
  print('Token info: $tokenInfo');
} catch (e) {
  print('Failed to get token info: $e');
}
```

## Permission Handling

The SDK uses the `permission_handler` package for cross-platform permission management:

```dart
Future<void> _requestNotificationPermission() async {
  final status = await Permission.notification.request();
  if (!status.isGranted) {
    throw Exception('Notification permission denied');
  }
}
```

## Example Implementation

Here's a complete example of how to implement push notifications:

```dart
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

class PushNotificationHandler {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();

  Future<void> setupPushNotifications() async {
    try {
      // 1. Request notification permission
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        throw Exception('Notification permission denied');
      }

      // 2. Register for push notifications
      await _klaviyo.registerForPushNotifications();
      
      print('Push notifications setup complete');
    } catch (e) {
      print('Failed to setup push notifications: $e');
    }
  }
}
```

## Migration from Firebase

If you're migrating from a Firebase-based implementation:

1. **Remove Firebase dependencies** from `pubspec.yaml`
2. **Remove Firebase imports** from your Dart code
3. **Update push registration calls** to use `_klaviyo.registerForPushNotifications()`
4. **Implement native token handling** in iOS AppDelegate (if not already done)
5. **Test push notifications** to ensure they still work

## Benefits of This Approach

1. **No Firebase conflicts**: Eliminates modular header issues
2. **Smaller app size**: Fewer dependencies
3. **Native integration**: Direct integration with platform push services
4. **Simpler setup**: Less configuration required
5. **Better performance**: No additional Firebase overhead

## Troubleshooting

### iOS Issues

- **No push token received**: Check that `didRegisterForRemoteNotificationsWithDeviceToken` is implemented
- **Permission denied**: Ensure notification permissions are requested before registration
- **Simulator issues**: Push notifications don't work in iOS Simulator, test on real device

### Android Issues

- **FCM not working**: Ensure `google-services.json` is present if using FCM features
- **Permission issues**: Check that `POST_NOTIFICATIONS` permission is handled for Android 13+
- **Token not set**: Verify that the native Klaviyo SDK is properly initialized

### General Issues

- **SDK not initialized**: Ensure `KlaviyoSDK().initialize()` is called before push registration
- **Network issues**: Check internet connectivity for token registration
- **Token validation**: Verify tokens are being sent to Klaviyo backend

## Testing

1. **Use the example app** to test push registration
2. **Send test notifications** through Klaviyo dashboard
3. **Check device logs** for any error messages
4. **Verify token registration** in Klaviyo profile data

This approach provides a cleaner, more maintainable solution for push notifications without Firebase dependencies. 