⚠️ STILL WORK IN PROGRESS AND NOT READY FOR PRODUCTION APPs YET ⚠️


# Klaviyo Flutter SDK

A Flutter plugin that provides a wrapper around the native Klaviyo SDKs for iOS and Android. This SDK allows you to integrate Klaviyo's powerful marketing automation features into your Flutter applications.

## Features

- **Profile Management**: Set user profiles, emails, phone numbers, and custom properties
- **Event Tracking**: Track custom events and user interactions
- **Push Notifications**: Register for and handle push notifications (Automatic Token handling)
- **In-App Forms**: Display and manage in-app forms for lead capture
- **Geofencing**: Observe geofences for location-based event tracking

## Installation

### 1. Add the dependency

Add `klaviyo_flutter_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  klaviyo_flutter_sdk: ^0.1.0-alpha.1
```

### 2. Platform Setup

#### iOS Setup

**1. Install Pods**

The required native iOS dependencies are automatically included via the plugin's podspec. Run `pod install` in the `ios` directory to install them:
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

**Requirements:**
- `minSdkVersion` 23+
- `compileSdkVersion` 34+
- Kotlin 1.8.0+

The Android SDK is automatically included as a dependency by the Flutter plugin. Required permissions are also automatically added via manifest merging.

**MainActivity Setup (Required for Push Notification Tracking)**

To track when users open push notifications, you need to handle intents in your `MainActivity`. See the [example MainActivity.kt](example/android/app/src/main/kotlin/com/klaviyo/flutterexample/MainActivity.kt) for a complete implementation.

Add the following to your `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import android.content.Intent
import android.os.Bundle
import com.klaviyo.analytics.Klaviyo
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle notification intent on cold start (app not running)
        intent?.let { Klaviyo.handlePush(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle notification intent on warm start (app already running)
        Klaviyo.handlePush(intent)
    }
}
```

**Why both methods?**
- `onCreate`: Handles notifications when app is launched from scratch (cold start)
- `onNewIntent`: Handles notifications when app is already running (warm start)

**KlaviyoPushService Declaration (Required for Push Notification Tracking)**

To ensure Klaviyo can properly track and handle push notifications, you must declare the `KlaviyoPushService` in your `android/app/src/main/AndroidManifest.xml`. This service intercepts FCM messages before Flutter's default `FirebaseMessagingService` processes them, allowing Klaviyo to track opens, handle rich push, and process notification data.

Add this service declaration inside the `<application>` tag:

```xml
<service
    android:name="com.klaviyo.pushFcm.KlaviyoPushService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

**Why is this required?**
- Without this declaration, Flutter's `firebase_messaging` plugin will intercept all FCM messages first
- Klaviyo won't be able to track notification opens or handle rich push features
- The service declaration ensures Klaviyo processes the notification before Flutter

See the [example AndroidManifest.xml](example/android/app/src/main/AndroidManifest.xml#L72-L81) for a complete implementation.

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
  );

  runApp(MyApp());
}
```

### 2. Profile Management

```dart
// Set a complete profile
final profile = KlaviyoProfile(
  email: 'user@test.com',
  firstName: 'John',
  lastName: 'Doe',
  phoneNumber: '+2125557890',
  properties: {
    'plan': 'premium',
    'signup_date': DateTime.now().toIso8601String(),
  },
);

await KlaviyoSDK().setProfile(profile);
```

```dart
// Set individual properties
await KlaviyoSDK().setEmail('user@example.com');
await KlaviyoSDK().setPhoneNumber('+1234567890');
await KlaviyoSDK().setExternalId('user123');
await KlaviyoSDK().setProfileProperties({
  'preferences': {'notifications': true},
});
```

### 3. Event Tracking

```dart
// Track a simple event using a predefined metric
final openedAppEvent = KlaviyoEvent(
  name: EventMetric.openedApp,
  properties: {
    'source': 'home_screen',
  },
);
await klaviyo.createEvent(openedAppEvent);

// Track a custom event
final customEvent = KlaviyoEvent.custom(
  metric: 'User Completed Tutorial',
  properties: {
    'tutorial_id': 'intro_v2',
    'completion_time_seconds': 245,
  },
);
await klaviyo.createEvent(customEvent);

// Track a purchase event with value
final purchaseEvent = KlaviyoEvent.custom(
  metric: 'Purchase Completed',
  properties: {
    'currency': 'USD',
    'product_id': 'prod_123',
    'product_name': 'Premium Subscription',
  },
  value: 99.99,
);
await klaviyo.createEvent(purchaseEvent);
```

### 4. Push Notifications

#### Prerequisites

**Platform-Specific Setup:**
- **Android**: Review [Android SDK Push Notifications](https://github.com/klaviyo/klaviyo-android-sdk#push-notifications) documentation for Firebase setup requirements
- **iOS**: Review [iOS SDK Push Notifications](https://github.com/klaviyo/klaviyo-swift-sdk#push-notifications) documentation for APNs setup requirements

**Key Requirements:**
- Firebase project configured (for both platforms)
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) added to your project
- Push notifications configured in your [Klaviyo account settings](https://help.klaviyo.com/hc/en-us/articles/14750928993307)

#### Requesting Notification Permissions

Requesting user permission to display notifications can be managed from the Flutter code,
or from platform-specific native code. Note that either of these approaches is sufficient
to inform the Klaviyo SDK of the permission change. If managing permissions from Flutter code,
you may use a third-party package (such as
[firebase_messaging](https://pub.dev/packages/firebase_messaging) or
[permission_handler](https://pub.dev/packages/permission_handler)) to handle permissions requests.

#### Token Collection

The Klaviyo SDK needs to register the device's push token to send notifications. You can choose between two approaches:

##### Option A: Manual Token Management with Firebase Messaging (Recommended)

If your app already uses Firebase Messaging for other features, or you need more control over token handling, you can manually fetch tokens and pass them to Klaviyo:

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
  });
  // On iOS, if the APNs token changes, the OS usually relaunches the app
  // or triggers distinct native callbacks.
}
```

**When to use this option:**
- You're already using `firebase_messaging` for other features (e.g., foreground message handling)
- You need to send the same token to multiple push providers
- You want explicit control over token refresh handling

##### Option B: Using the SDK's Built-in Registration

The simplest approach - the SDK automatically fetches the push token on both platforms without requiring you to add `firebase_messaging` as a direct dependency:

```dart
// Register for push notifications
// iOS: Triggers APNs registration and automatically registers it with Klaviyo
// Android: Fetches the FCM token and automatically registers it with Klaviyo
await klaviyo.registerForPushNotifications();

// Listen for token events via the push notification stream
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

**How it works:**
- **iOS**: Calls the native APNs registration API and automatically forwards the token to Klaviyo
- **Android**: Uses the native Firebase SDK to fetch the FCM token and registers it with Klaviyo
- Token updates are emitted through the `onPushNotification` stream
- No need to add `firebase_messaging` as a direct dependency in your Flutter project

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
// Register for in-app forms with default session timeout (1 hour)
await klaviyo.registerForInAppForms();

// Register with a custom session timeout
final config = InAppFormConfig(
  sessionTimeoutDuration: Duration(minutes: 30),
);
await klaviyo.registerForInAppForms(configuration: config);

// Register with infinite session timeout (no timeout)
final infiniteConfig = InAppFormConfig.infinite();
await klaviyo.registerForInAppForms(configuration: infiniteConfig);

// Unregister from in-app forms
await klaviyo.unregisterFromInAppForms();

// Listen for form events
klaviyo.onFormEvent.listen((event) {
  print('Form event: ${event['type']}');
});
```

**Session Timeout Configuration:**

The `sessionTimeoutDuration` parameter controls how long forms remain eligible to display after app backgrounding. For more details on form behavior and configuration, see the native SDK documentation:
- [Android In-App Forms](https://github.com/klaviyo/klaviyo-android-sdk#in-app-messages)
- [iOS In-App Forms](https://github.com/klaviyo/klaviyo-swift-sdk#in-app-messages)

### 8. Deep Linking

Klaviyo supports [Deep Links](https://help.klaviyo.com/hc/en-us/articles/14750403974043) for tracking link clicks and navigating to specific content within your app. This works with push notifications, in-app messages, and Klaviyo tracking links.

#### Prerequisites

1. Set up deep linking in your Flutter app using one of these approaches:
   - [go_router](https://pub.dev/packages/go_router) (recommended by Flutter team)
   - [app_links](https://pub.dev/packages/app_links) or [uni_links](https://pub.dev/packages/uni_links)
   - Flutter's built-in `WidgetsBindingObserver`

2. Configure platform-specific deep linking:
   - **iOS**: [Universal Links Setup](https://github.com/klaviyo/klaviyo-swift-sdk#deep-linking)
   - **Android**: Configure intent filters in your `AndroidManifest.xml` (see below)

#### Android Deep Linking Configuration

The [example AndroidManifest.xml](example/android/app/src/main/AndroidManifest.xml#L31-L60) demonstrates three types of deep links:

**1. Custom URL Schemes** (e.g., `myapp://product/123`)

Add to your `MainActivity` in `AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="YOUR_CUSTOM_SCHEME" />
</intent-filter>
```

Additionally, this can be configured natively on Flutter. Just be sure that the deeplink path you use for actions matches your app package schema.

**2. App Links (Universal Links)** (e.g., `https://yourdomain.com/product/123`)

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" />
    <data android:host="yourdomain.com" />
</intent-filter>
```

**3. Klaviyo Universal Tracking Links** (e.g., `https://trk.yourdomain.com/u/abc123`)

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" />
    <data android:host="trk.send.yourdomain.com" />
    <data android:pathPrefix="/u/" />
</intent-filter>
```

**Testing Deep Links:**

```bash
# Test custom URL scheme
adb shell am start -W -a android.intent.action.VIEW -d "myapp://product/123" com.your.package

# Test app link
adb shell am start -W -a android.intent.action.VIEW -d "https://yourdomain.com/product/123" com.your.package

# Test Klaviyo tracking link
adb shell am start -W -a android.intent.action.VIEW -d "https://trk.yourdomain.com/u/abc123" com.your.package
```

For complete Android App Links setup including domain verification, see the [Android SDK Deep Linking Guide](https://github.com/klaviyo/klaviyo-android-sdk#deep-linking).

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

- `initialize({required String apiKey})` - Initialize the SDK
- `setProfile(KlaviyoProfile profile)` - Set a complete user profile
- `setEmail(String email)` - Set user email
- `setPhoneNumber(String phoneNumber)` - Set user phone number
- `setExternalId(String externalId)` - Set external user ID
- `getEmail()` - Get user email
- `getPhoneNumber()` - Get user phone number
- `getExternalId()` - Get external user ID
- `setProfileProperties(Map<String, dynamic> properties)` - Set custom profile properties
- `setProfileAttribute(String propertyKey, dynamic value)` - Set a single profile attribute
- `setLocation(KlaviyoLocation location)` - Set profile location
- `createEvent(KlaviyoEvent event)` - Create a new event to track a profile's activity
- `registerForPushNotifications()` - Register for push notifications (iOS: triggers APNs registration, Android: fetches FCM token)
- `setPushToken(String token)` - Set push notification token (usually handled automatically by native SDKs)
- `getPushToken()` - Get current push token
- `registerForInAppForms({InAppFormConfig? configuration})` - Register for in-app forms
- `unregisterFromInAppForms()` - Unregister from in-app forms
- `registerGeofencing()` - Begin monitoring geofences (requires location permissions)
- `unregisterGeofencing()` - Stop monitoring all geofences
- `handleUniversalTrackingLink(String url)` - Validates and handles Klaviyo universal tracking links, returns `bool`
- `resetProfile()` - Reset user profile
- `setBadgeCount(int count)` - Set the badge count on the app icon (iOS only)
- `setLogLevel(KlaviyoLogLevel logLevel)` - Set logging level (Flutter-side only)
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
  required EventMetric name,
  Map<String, dynamic>? properties,
  double? value,
  String? uniqueId,
})

// Convenience constructor for custom events
KlaviyoEvent.custom({
  required String metric,
  Map<String, dynamic>? properties,
  double? value,
  String? uniqueId,
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
// Default configuration (1 hour session timeout)
InAppFormConfig({
  Duration? sessionTimeoutDuration,
})

// Infinite session timeout (no timeout)
InAppFormConfig.infinite()
```

### Enums

#### KlaviyoLogLevel

- `none` - No logging
- `error` - Error messages only
- `warning` - Warning and error messages
- `info` - Info, warning, and error messages
- `debug` - All messages including debug

#### EventMetric

Predefined event metrics:
- `EventMetric.openedApp` - The 'Opened App' event
- `EventMetric.viewedProduct` - The 'Viewed Product' event
- `EventMetric.addedToCart` - The 'Added to Cart' event
- `EventMetric.startedCheckout` - The 'Started Checkout' event

Custom event metrics:
- `EventMetric.custom(String name)` - Create a custom event with any name

## Example

See the `example/` directory for a complete working example.

## Troubleshooting

### Android Issues

#### Push Notifications Not Tracking Opens

**Problem:** Push notifications arrive but opens are not tracked in Klaviyo.

**Solutions:**
1. **Verify MainActivity setup:** Ensure `Klaviyo.handlePush(intent)` is called in both `onCreate` and `onNewIntent` methods. See [example MainActivity.kt](example/android/app/src/main/kotlin/com/klaviyo/flutterexample/MainActivity.kt)
2. **Check launch mode:** In `AndroidManifest.xml`, your MainActivity should use `android:launchMode="singleTop"` or `singleTask`
3. **Enable debug logging:** Add to `AndroidManifest.xml` to see detailed logs:
   ```xml
   <meta-data
       android:name="com.klaviyo.core.log_level"
       android:value="1" />
   ```
4. **Check logcat:** Run `adb logcat | grep -i klaviyo` to see if push opens are being processed

#### Push Notifications Not Displaying

**Problem:** Notifications don't appear in the system tray.

**Solutions:**
1. **Check Firebase setup:**
   - Verify `google-services.json` is in `android/app/`
   - Ensure Firebase plugin is applied in `android/app/build.gradle`
   - Test with Firebase Console first to rule out Klaviyo-specific issues
2. **Check notification permission:**
   - On Android 13+, runtime permission is required
   - Verify permission is granted: Use `permission_handler` to check status
3. **Check Klaviyo account configuration:** Verify FCM server key is configured in [Klaviyo settings](https://help.klaviyo.com/hc/en-us/articles/14750928993307)

#### Push Tokens Not Being Set

**Problem:** Tokens are not being registered with Klaviyo.

**Solutions:**
1. **Verify Firebase is configured:** Ensure Firebase is properly initialized before calling `FirebaseMessaging.instance.getToken()`
2. **Check SDK initialization:** Call `klaviyo.initialize()` before `klaviyo.setPushToken()`
3. **Check network connectivity:** Token registration requires internet connection
4. **Verify token is retrieved:** Add logging to confirm token is not null:
   ```dart
   final token = await FirebaseMessaging.instance.getToken();
   print('FCM Token: $token'); // Should not be null
   ```

#### Deep Links Not Working

**Problem:** Deep links don't open the app or navigate correctly.

**Solutions:**
1. **Verify intent filters:** Check `AndroidManifest.xml` has correct intent filters for your URL schemes. See [example AndroidManifest.xml](example/android/app/src/main/AndroidManifest.xml#L31-L60)
2. **Test with adb:**
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "yourscheme://path" com.your.package
   ```
3. **Check launchMode:** Use `singleTop` or `singleTask` to avoid creating multiple activity instances
4. **Verify App Links (HTTPS links):** Run `adb shell pm verify-app-links --re-verify com.your.package` and ensure `assetlinks.json` is accessible

#### Build Issues

**Problem:** Build fails with SDK-related errors.

**Solutions:**
1. **MinSdk error:** Ensure `android/app/build.gradle` has `minSdkVersion 23` or higher
2. **Duplicate class errors:** Remove any direct references to `com.klaviyo:klaviyo-android-sdk` from your gradle files (the Flutter plugin includes it automatically)
3. **Manifest merger errors:** Check for conflicting permissions or activities in your manifest

### iOS Issues

For iOS-specific troubleshooting, refer to the [iOS SDK documentation](https://github.com/klaviyo/klaviyo-swift-sdk#troubleshooting).

### Common Issues (Both Platforms)

#### Events Not Showing in Klaviyo Dashboard

**Problem:** Events are sent but don't appear in the dashboard.

**Solutions:**
1. **Wait 5-10 minutes:** There's a processing delay for events to appear
2. **Verify API key:** Ensure you're using the correct public API key
3. **Check profile is set:** Events require a profile (email, phone, or external_id). Call `klaviyo.setEmail()` or `klaviyo.setExternalId()` before tracking events
4. **Check account status:** Verify your Klaviyo account is active

#### SDK Not Initializing

**Problem:** SDK methods throw "not initialized" errors.

**Solutions:**
1. **Call initialize early:** Call `klaviyo.initialize()` in `main()` before `runApp()`:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     final klaviyo = KlaviyoSDK();
     await klaviyo.initialize(apiKey: 'YOUR_API_KEY');
     runApp(MyApp());
   }
   ```
2. **Check for async issues:** Ensure `await` is used when calling `initialize()`

### Getting Additional Help

- **Native SDK Documentation:**
  - [Android SDK](https://github.com/klaviyo/klaviyo-android-sdk)
  - [iOS SDK](https://github.com/klaviyo/klaviyo-swift-sdk)
- **Klaviyo Support:** [https://help.klaviyo.com/](https://help.klaviyo.com/)
- **GitHub Issues:** Report bugs at [https://github.com/klaviyo/klaviyo-flutter-sdk/issues](https://github.com/klaviyo/klaviyo-flutter-sdk/issues)

When reporting issues, include:
- SDK version
- Flutter version
- Platform (Android/iOS) and OS version
- Steps to reproduce
- Relevant logs (with debug logging enabled)
- Code snippets showing SDK usage

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
