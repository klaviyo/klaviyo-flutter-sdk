# Klaviyo Flutter SDK

A Flutter plugin that provides a wrapper around the native Klaviyo SDKs for iOS and Android. This SDK allows you to integrate Klaviyo's powerful marketing automation features into your Flutter applications.

## Features

- **Profile Management**: Set user profiles, emails, phone numbers, and custom properties
- **Event Tracking**: Track custom events and user interactions
- **Push Notifications**: Register for and handle push notifications (Automatic Token handling)
- **Rich Push**: Display images within push notifications
- **Badge Count**: Set and manage app icon badge count (iOS only)
- **In-App Forms**: Display and manage in-app forms for lead capture
- **Cross-Platform**: Works on both iOS and Android using native SDKs
- **Real-time Updates**: Stream-based profile updates and event handling

## Installation

### 1. Add the dependency

Add `klaviyo_flutter_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  klaviyo_flutter_sdk: ^1.0.0
```

### 2. Platform Setup

#### iOS Setup

**1. Install Pods**

Add the Klaviyo Swift SDK to your `ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Add Klaviyo Swift SDK
  pod 'KlaviyoSwiftSDK'
end
```

Run `pod install` in the `ios` directory:
```bash
cd ios && pod install
```

**2. Enable Capabilities (Required)**

Open your project in Xcode (`ios/Runner.xcworkspace`), select the **Runner** target, go to the **Signing & Capabilities** tab, and add the following capabilities:
* **Push Notifications** (Required for APNs)
* **Background Modes** -> Check **Remote notifications** (Required for silent push updates)

**3. AppDelegate Setup (Required)**

To ensure push notifications display correctly while the app is in the foreground and to track "Open" events reliably, you need to implement the notification delegate methods in your `ios/Runner/AppDelegate.swift`.

Please ensure you make the following changes to your existing AppDelegate:

1.  **Import the plugin module:** `import klaviyo_flutter_sdk`
2.  **Set the Notification Delegate:** Assign `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunching`.
3.  **Forward Notification Events:** Implement (or update) the `userNotificationCenter` methods to forward events to the Klaviyo SDK.

**Note on Push Token Handling:** The plugin automatically intercepts `didRegisterForRemoteNotificationsWithDeviceToken` to capture the APNs token. If you need to override this method in your AppDelegate (e.g., to also send the token to another push service), make sure to call `super`:

```swift
override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    // Call super to ensure the Klaviyo plugin receives the token
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)

    // Your custom token handling here
}
```

Here is an example of what the integration looks like:

```swift
import UIKit
import Flutter
import klaviyo_flutter_sdk // <--- Add this import

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // <--- Add this line to handle foreground notifications and taps
        UNUserNotificationCenter.current().delegate = self

        // ... Your existing setup code ...

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // <--- Add or update this method to handle Foreground Notifications
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when the app is open
        completionHandler([.banner, .sound, .badge])

        // ... Your custom logic (if any) ...
    }

    // <--- Add or update this method to forward Tap Events
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Forward the "Open" event to the Klaviyo SDK
        KlaviyoFlutterSdkPlugin.shared.handleNotificationResponse(response)

        // ... Your custom logic (if any) ...

        // Complete the system callback
        completionHandler()
    }

    // <--- Add this method to handle Silent Push Notifications (Optional)
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Forward silent push to Klaviyo plugin
        KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo: userInfo)

        // ... Your custom logic (if any) ...

        // You MUST call the completion handler within ~30 seconds.
        // Failing to do so will cause iOS to throttle or stop delivering
        // silent push notifications to your app.
        completionHandler(.newData)
    }
}
```

#### Android Setup

1. Add the Klaviyo Android SDK to your `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.klaviyo:klaviyo-android-sdk:1.0.0'
}
```

2. Add required permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### Enabling Geofencing (Optional)

The Klaviyo Flutter SDK supports geofencing, but the **full location module with Play Services is not included by default**. The SDK includes lightweight location interfaces (`location-core` on Android, compile-time checks on iOS) that allow you to call geofencing methods, but they will return errors unless you explicitly enable the full location module.

#### Android

Add to `android/gradle.properties`:

```properties
klaviyoIncludeLocation=true
```

This:
- Includes the full `location` module with Google Play Services implementation
- Adds these permissions to your merged manifest:
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_BACKGROUND_LOCATION`

#### iOS

Add to `ios/Podfile` before `flutter_install_all_ios_pods`:

```ruby
ENV['KLAVIYO_INCLUDE_LOCATION'] = 'true'
```

This includes the `KlaviyoLocation` pod with full geofencing support. You'll also need location permission descriptions in `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location for geofencing features.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location for geofence monitoring.</string>
```

#### Error Behavior

**Without the full location module (default):**
- Geofencing methods (`registerGeofencing()`, `unregisterGeofencing()`, `getCurrentGeofences()`) will return:
  - **Error code**: `GEOFENCING_NOT_AVAILABLE`
  - **Message**: "Geofencing requires the full location module. Add 'klaviyoIncludeLocation=true' to gradle.properties" (Android) or "...to your podfile" (iOS)

**With the full location module enabled:**
- Full geofencing functionality available

### Disabling In-App Forms (Optional)

In-app forms are **enabled by default**. To opt out:

#### Android

Add to `android/gradle.properties`:

```properties
klaviyoIncludeForms=false
```

#### iOS

Add to `ios/Podfile` before `flutter_install_all_ios_pods`:

```ruby
ENV['KLAVIYO_INCLUDE_FORMS'] = 'false'
```

#### Error Behavior

**Without the forms module:**
- Forms methods (`registerForInAppForms()`, `unregisterFromInAppForms()`) will log an error and no-op gracefully
- Error code: `FORMS_NOT_AVAILABLE`
- Smaller SDK footprint

## Usage

### 1. Initialize the SDK

```dart
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final klaviyo = KlaviyoSDK();
  await klaviyo.initialize(
    apiKey: 'YOUR_KLAVIYO_PUBLIC_API_KEY',
    logLevel: KlaviyoLogLevel.debug,
    environment: PushEnvironment.development,
  );

  runApp(MyApp());
}
```

### 2. Profile Management

```dart
// Set a complete profile
final profile = KlaviyoProfile(
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
  phoneNumber: '+1234567890',
  properties: {
    'plan': 'premium',
    'signup_date': DateTime.now().toIso8601String(),
  },
);
await klaviyo.setProfile(profile);

// Set individual properties
await klaviyo.setEmail('user@example.com');
await klaviyo.setPhoneNumber('+1234567890');
await klaviyo.setExternalId('user123');
await klaviyo.setProfileProperties({
  'preferences': {'notifications': true},
});
```

### 3. Event Tracking

```dart
// Track a simple event
await klaviyo.track('App Opened', {
  'source': 'flutter_sdk',
  'timestamp': DateTime.now().toIso8601String(),
});

// Track a complex event
final event = KlaviyoEvent(
  name: 'Purchase Completed',
  properties: {
    'value': 99.99,
    'currency': 'USD',
    'product_id': 'prod_123',
  },
  timestamp: DateTime.now(),
);
await klaviyo.createEvent(event);
```

### 4. Push Notifications

#### Option A: Using Firebase Messaging (Recommended)

If your app uses Firebase Messaging, obtain the token from Firebase and pass it
to Klaviyo:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Get token from Firebase and pass to Klaviyo
if (Platform.isIOS) {
  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

  if (apnsToken != null) {
    await klaviyo.setPushToken(apnsToken);
    print("Sent APNs token to Klaviyo");
  } else {
    print("APNs token was null. Waiting for refresh...");
  }
} else if (Platform.isAndroid) {
  String? fcmToken = await FirebaseMessaging.instance.getToken();

  if (fcmToken != null) {
    await klaviyo.setPushToken(fcmToken);
    print("Sent FCM token to Klaviyo");
  }
}

// Listen for Token Refreshes (Important for long-running apps)
// Note: On iOS, this stream returns the FCM token, not APNs.
// Native APNs token changes are rare, but for Android this is crucial.
if (Platform.isAndroid) {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    klaviyo.setPushToken(newToken);
  }
  // On iOS, if the APNs token changes, the OS usually relaunches the app
  // or triggers distinct native callbacks.
});
```

#### Option B: Using the SDK's Built-in Registration

If you don't want to add `firebase_messaging` as a dependency, the Klaviyo Flutter
SDK provides a built-in method to register for push notifications:

```dart
// Register for push notifications
// iOS: Triggers APNs registration, captures the token, then sets it on the Klaviyo account
// Android: No-op (requires FCM setup)
await klaviyo.registerForPushNotifications();

// If you need to access token updates, you may subscribe to
// the push event stream and listen for token events
klaviyo.onPushNotification.listen((event) {
  switch (event['type']) {
    case 'push_token_received':
      final token = event['data']['token'];
      print('Token received: $token');
      break;
    case 'push_token_error':
      final error = event['data']['error'];
      print('Token error: $error');
      break;
  }
});
```

#### Handling Push Notification Opens

```dart
// Listen for notification open events
klaviyo.onPushNotification.listen((event) {
  if (event['type'] == 'push_notification_opened') {
    print('Notification opened: ${event['data']}');
  }
});
```

### 5. Rich Push

[Rich Push](https://help.klaviyo.com/hc/en-us/articles/16917302437275) is the ability to add images to
push notification messages. On iOS, you will need to implement an extension service to attach images to notifications.
No additional setup is needed to support rich push on Android.

- [Android](https://github.com/klaviyo/klaviyo-android-sdk#Rich-Push)
- [iOS](https://github.com/klaviyo/klaviyo-swift-sdk#Rich-Push)

### 6. Badge Count (iOS Only)

Klaviyo supports setting or incrementing the badge count on iOS when you send a push notification.
To enable this functionality, you will need to implement a notification service extension and app group
as detailed in the [Swift SDK installation instructions](https://github.com/klaviyo/klaviyo-swift-sdk?tab=readme-ov-file#installation).
See the [badge count documentation](https://github.com/klaviyo/klaviyo-swift-sdk?tab=readme-ov-file#badge-count) for more details and the example app for reference.
Android automatically handles badge counts, and no additional setup is needed.

### 7. In-App Forms

```dart
// Register for in-app forms
final config = InAppFormConfig(
  enabled: true,
  autoShow: true,
  position: 'bottom',
  theme: {
    'primary_color': '#007bff',
    'text_color': '#333333',
  },
);
await klaviyo.registerForInAppForms(configuration: config);

// Show a specific form
final success = await klaviyo.showForm('newsletter_signup',
  customData: {'source': 'flutter_app'});

// Hide a form
await klaviyo.hideForm('newsletter_signup');
```

### 8. Deep Linking

Klaviyo supports [Deep Links](https://help.klaviyo.com/hc/en-us/articles/14750403974043) for tracking link clicks and navigating to specific content within your app. This works with push notifications, in-app messages, and Klaviyo tracking links.

#### Prerequisites

1. Set up deep linking in your Flutter app using one of these approaches:
   - [go_router](https://pub.dev/packages/go_router) (recommended by Flutter team)
   - [app_links](https://pub.dev/packages/app_links) or [uni_links](https://pub.dev/packages/uni_links)
   - Flutter's built-in `WidgetsBindingObserver`

2. Configure platform-specific deep linking:
   - [iOS Universal Links Setup](https://github.com/klaviyo/klaviyo-swift-sdk#deep-linking)
   - [Android App Links Setup](https://github.com/klaviyo/klaviyo-android-sdk#deep-linking)

#### Integration with go_router

Use go_router's `redirect` callback to pass URLs to Klaviyo:

```dart
import 'package:go_router/go_router.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(),
      routes: [
        GoRoute(
          path: 'product/:id',
          builder: (context, state) => ProductScreen(
            productId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    // Fire-and-forget - Klaviyo tracks the link in the background
    final klaviyo = KlaviyoSDK();
    klaviyo.handleUniversalTrackingLink(state.uri.toString());

    // Continue with normal navigation
    return null;
  },
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final klaviyo = KlaviyoSDK();
  await klaviyo.initialize(apiKey: 'YOUR_API_KEY');

  runApp(MaterialApp.router(routerConfig: router));
}
```

#### How It Works

1. **URL arrives** via go_router's routing system
2. **`redirect` callback fires** with the URL
3. **Call `handleUniversalTrackingLink()`** - validates and returns immediately
4. **Returns `true`** if it's a Klaviyo tracking link (format: `https://domain/u/...`), `false` otherwise
5. **Native SDK tracks** the click event in the background (fire-and-forget)
6. **Native SDK resolves** the link and your Flutter routing library handles the final destination

**Note**: `handleUniversalTrackingLink()` is synchronous - it validates the URL and returns a bool immediately, while the native tracking happens asynchronously in the background.

### 9. Profile Reset (Logout)

```dart
// Reset profile when user logs out
await klaviyo.resetProfile();
```

## API Reference

### KlaviyoSDK

The main SDK class that provides all functionality.

#### Methods

- `initialize(apiKey, logLevel, environment, configuration)` - Initialize the SDK
- `setProfile(profile)` - Set a complete user profile
- `setEmail(email)` - Set user email
- `setPhoneNumber(phoneNumber)` - Set user phone number
- `setExternalId(externalId)` - Set external user ID
- `setProfileProperties(properties)` - Set custom profile properties
- `createEvent(event)` - Create a new event to track a profile's activity
- `setProfileAttribute(propertyKey, value)` - Set a single profile attribute
- `registerForPushNotifications()` - Register for push notifications (iOS: triggers APNs registration, Android: fetches FCM token)
- `setPushToken(token, environment)` - Set push notification token (usually handled automatically by native SDKs)
- `getPushToken()` - Get current push token
- `registerForInAppForms(configuration)` - Register for in-app forms
- `showForm(formId, customData)` - Show a specific form
- `hideForm(formId)` - Hide a specific form
- `handleUniversalTrackingLink(url)` - Validates and handles Klaviyo universal tracking links, returns `bool`
- `resetProfile()` - Reset user profile
- `setBadgeCount(count)` - Set the badge count on the app icon (iOS only)
- `setLogLevel(logLevel)` - Set logging level
- `dispose()` - Clean up resources

#### Properties

- `isInitialized` - Whether the SDK is initialized
- `apiKey` - Current API key
- `onPushNotification` - Stream of push notification events (token received, notification opened, errors)
- `onFormEvent` - Stream of in-app form events

### Models

#### KlaviyoProfile

```dart
KlaviyoProfile({
  String? email,
  String? phoneNumber,
  String? externalId,
  String? firstName,
  String? lastName,
  String? organization,
  String? title,
  String? image,
  KlaviyoLocation? location,
  Map<String, dynamic>? properties,
})
```

#### KlaviyoEvent

```dart
KlaviyoEvent({
  required String name,
  Map<String, dynamic>? properties,
  DateTime? timestamp,
})
```

#### KlaviyoLocation

```dart
KlaviyoLocation({
  required double latitude,
  required double longitude,
  String? address1,
  String? address2,
  String? city,
  String? region,
  String? country,
  String? zip,
})
```

#### InAppFormConfig

```dart
InAppFormConfig({
  bool? enabled,
  bool? autoShow,
  String? position,
  Map<String, dynamic>? theme,
})
```

### Enums

#### KlaviyoLogLevel

- `none` - No logging
- `error` - Error messages only
- `warning` - Warning and error messages
- `info` - Info, warning, and error messages
- `debug` - All messages including debug

#### PushEnvironment

- `development` - Development environment
- `production` - Production environment

## Example

See the `example/` directory for a complete working example.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please contact Klaviyo support or create an issue in this repository.

## Native SDK Dependencies

This Flutter SDK wraps the following native SDKs:

- **iOS**: [Klaviyo Swift SDK](https://github.com/klaviyo/klaviyo-swift-sdk)
- **Android**: [Klaviyo Android SDK](https://github.com/klaviyo/klaviyo-android-sdk)

Make sure to refer to the native SDK documentation for platform-specific features and requirements.
