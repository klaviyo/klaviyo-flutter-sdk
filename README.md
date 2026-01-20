# Klaviyo Flutter SDK

A Flutter plugin that provides a wrapper around the native Klaviyo SDKs for iOS and Android. This SDK allows you to integrate Klaviyo's powerful marketing automation features into your Flutter applications.

## Features

- **Profile Management**: Set user profiles, emails, phone numbers, and custom properties
- **Event Tracking**: Track custom events and user interactions
- **Push Notifications**: Register for and handle push notifications
- **Rich Push**: Display images within push notifications
- **Badge Count**: Set and manage app icon badge count (iOS)
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

1. Add the Klaviyo Swift SDK to your `ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Add Klaviyo Swift SDK
  pod 'KlaviyoSwiftSDK'
end
```

2. Run `pod install` in the `ios` directory:

```bash
cd ios && pod install
```

3. Add required permissions to `ios/Runner/Info.plist`:

```xml
<key>NSUserNotificationUsageDescription</key>
<string>We use notifications to keep you updated with important information.</string>
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
await klaviyo.trackEvent(event);
```

### 4. Push Notifications

```dart
// Register for push notifications
// iOS: Triggers APNs registration
// Android: No-op (FCM handles registration automatically)
await klaviyo.registerForPushNotifications();

// Get the current push token
final token = await klaviyo.getPushToken();
print('Push token: $token');

// Handle push notification events
klaviyo.profileStream.listen((profile) {
  print('Profile updated: ${profile?.email}');
});
```

### 5. Rich Push

[Rich Push](https://help.klaviyo.com/hc/en-us/articles/16917302437275) is the ability to add images to
push notification messages. On iOS, you will need to implement an extension service to attach images to notifications.
No additional setup is needed to support rich push on Android.

- [Android](https://github.com/klaviyo/klaviyo-android-sdk#Rich-Push)
- [iOS](https://github.com/klaviyo/klaviyo-swift-sdk#Rich-Push)

### 6. Badge Count (iOS Only)

// TODO: implement this section

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

### 8. Profile Reset (Logout)

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
- `track(name, properties)` - Track a simple event
- `trackEvent(event)` - Track a complex event
- `registerForPushNotifications()` - Register for push notifications (iOS: triggers APNs registration, Android: no-op)
- `setPushToken(token, environment)` - Set push notification token (usually handled automatically by native SDKs)
- `getPushToken()` - Get current push token
- `registerForInAppForms(configuration)` - Register for in-app forms
- `showForm(formId, customData)` - Show a specific form
- `hideForm(formId)` - Hide a specific form
- `resetProfile()` - Reset user profile
- `setBadgeCount(count)` - Set the badge count on the app icon (iOS only)
- `setLogLevel(logLevel)` - Set logging level
- `dispose()` - Clean up resources

#### Properties

- `isInitialized` - Whether the SDK is initialized
- `apiKey` - Current API key
- `currentProfile` - Current user profile
- `profileStream` - Stream of profile updates

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
