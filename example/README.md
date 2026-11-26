# Klaviyo Flutter SDK Example App

This example app demonstrates how to use the Klaviyo Flutter SDK with a user-friendly interface for testing all SDK features.

## Getting Started

### 1. API Key Setup

Open **Profile** and use its **API Key** field to configure your account:

- **Your API Key**: Replace this with your actual Klaviyo API key from your account
- **Where to Find**: Log into your Klaviyo account → Settings → API Keys → Public API Key

### 2. Initialize the SDK

1. Enter your API key in the text field
2. Tap **"Initialize SDK"** in **Profile**
3. Wait for the status to show "SDK initialized successfully!"
4. Once initialized, you can use all the SDK features

### 3. Reset and Change API Key

- If you need to test with a different API key, tap **"Reset SDK & Change API Key"** in **Profile**
- This clears the saved key so you can enter another one and reinitialize. Otherwise, the saved key is reused on later launches.

## Features Demonstrated

### 📋 Profile Management
- **Set Profile**: Create a complete user profile with email, name, phone, etc.
- **Set Email**: Update just the email address
- **Set Phone Number**: Update phone number
- **Set External ID**: Set a custom user identifier
- **Set Profile Properties**: Add custom properties to the profile
- **Reset Profile**: Clear the current profile (useful for testing logout)

### 📊 Event Tracking
- **Track Simple Event**: Send a basic event with properties
- **Track Complex Event**: Send an event with structured data (like a purchase)

### 📱 Push Notifications
- **Enable Push Notifications**: Request permission and register. The button becomes **Notifications Enabled** when permission is granted.
- **Push Token (tap to copy)**: Display and copy the current APNs or FCM token. Tokens and registration errors arrive through `onPushToken`.
- **Read Launch Tap**: Read the typed notification that launched the app with `getInitialPushNotification()`.
- **Badge Count** (iOS): Set or clear the badge using **Set** and **Clear**.

### 🎯 In-App Forms
- **Register for Forms**: Enable in-app forms that will show automatically based on Klaviyo targeting

### ⚙️ Configuration
For logging controls, see [SDK Logging](../README.md#sdk-logging). SDK integrations use `setLoggingEnabled(bool)`.

## Testing Location Permission Configurations

The SDK supports geofencing, but location functionality is **not included by default**. To test geofencing features, you must explicitly enable location.

### Default (Without Permissions)

```bash
flutter run
```

Geofencing methods will return "UNAVAILABLE" errors.

### With Location Enabled (For Geofencing)

#### Android

1. Add to `android/gradle.properties`:
   ```properties
   klaviyoIncludeLocation=true
   ```

2. Rebuild:
   ```bash
   cd android && ./gradlew clean && cd .. && flutter clean && flutter run
   ```

#### iOS

1. The example builds with Swift Package Manager, which always links `KlaviyoLocation`, so there's no flag to set. (In your own app, CocoaPods builds need `ENV['KLAVIYO_INCLUDE_LOCATION'] = 'true'` in `ios/Podfile`; see the main README.)

2. Add location permission descriptions and the `location` background mode to `ios/Runner/Info.plist`. Without `location` under `UIBackgroundModes`, iOS won't allow background location updates, so geofencing won't start:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We use your location for geofencing features.</string>

   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>We need background location for geofence monitoring.</string>

   <key>UIBackgroundModes</key>
   <array>
       <string>location</string>
   </array>
   ```

3. Rebuild:
   ```bash
   flutter clean && flutter run
   ```

### Expected Behavior

**Without location permissions (default):**
- Geofencing methods (`registerGeofencing()`, `unregisterGeofencing()`, `getCurrentGeofences()`) return errors
- Location permissions do NOT appear in manifest/Info.plist
- No location permissions requested from users

**With location permissions enabled:**
- Geofencing methods work correctly
- Location permissions appear in manifest/Info.plist
- Location permissions requested at runtime

### Verification Steps

#### Android Manifest Verification

```bash
# Default (should NOT include permissions)
cd android && ./gradlew :app:processDebugManifest
cat app/build/intermediates/merged_manifests/debug/AndroidManifest.xml | grep ACCESS_FINE_LOCATION
# Expected: No output (permission not found)

# With klaviyoIncludeLocation=true
echo "klaviyoIncludeLocation=true" >> android/gradle.properties
cd android && ./gradlew clean && ./gradlew :app:processDebugManifest
cat app/build/intermediates/merged_manifests/debug/AndroidManifest.xml | grep ACCESS_FINE_LOCATION
# Expected: Shows the permission line
```

#### iOS Package Verification

```bash
flutter build ios --no-codesign
grep -o '"identity" : "klaviyo-swift-sdk"' ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
# Expected: klaviyo-swift-sdk is resolved; KlaviyoLocation is one of its products and is always linked
```

## Push Notification Testing

### Typed push streams

- The Push tab listens to `onPushToken` (`KlaviyoPushToken`) and shows the token type or registration error. Tap the displayed token to copy it.
- `onPushOpened` (`KlaviyoPushOpened`) reports body, action-button and web-link taps. The Push status shows tap details. A tap carrying custom pairs also opens a **Push Opened** dialog.
- `onPushData` (`KlaviyoPushData`) shows a **Push Data Received** dialog for qualifying foreground pushes.
- `main()` registers `KlaviyoSDK.onBackgroundPushData(klaviyoBackgroundPushDataHandler)` before `runApp`. Background/killed delivery logs `Klaviyo background push data: ...` in the device console instead of showing UI.
- **Read Launch Tap** calls `getInitialPushNotification()` and shows the recorded launch tap, or `null`. Repeated reads return the same tap until profile reset.

The example also registers a Firebase background handler on Android to exercise coexistence. See the main [push-data guide](../README.md#push-data) for service routing, iOS Background Processing requirements and delivery limits.

### Smoke steps

1. Initialize with an account you control, identify a test profile in **Profile**, and visit **Push**.
2. Tap **Enable Push Notifications** and allow permission. If permission is already granted, the button reads **Notifications Enabled**. Confirm that a push token appears. There is no separate token-fetch button.
3. Send that profile a Klaviyo visible push with key/value pairs, for example `test_key: test_value`, while the app is foregrounded. Expect **Push Data Received** with those pairs.
4. Background the app and send another qualifying push. Look for the background-handler log. On iOS, enable **Background Processing** for the message and use real APNs delivery. iOS background wakeups are best effort, so an absent log alone is not a definitive failure.
5. Tap the notification. Expect an `onPushOpened` status update and a **Push Opened** dialog when it contains custom pairs. Arrival data and the later tap are separate events.
6. To exercise a launch tap, terminate the process without force-stopping Android, send a visible push, and tap it to launch the app. Tap **Read Launch Tap** and confirm it records that tap. Reading it again should show the same value.

Use real APNs/FCM delivery for background and terminated-state checks. Simulated notifications alone do not verify those paths. On iOS, force-quitting prevents background push delivery until the app is reopened or the device restarts. Hand-built iOS push-data payloads need the Klaviyo `_k` marker. See [iOS delivery rules](../README.md#ios).

## API Key Information

### Your Real API Key
- Get this from your Klaviyo account settings
- Format: Usually a short alphanumeric string (6-8 characters)
- Use this to see real data in your Klaviyo dashboard

### Finding Your API Key
1. Log into your Klaviyo account
2. Go to **Settings** → **API Keys**
3. Copy your **Public API Key** (not the Private API Key)
4. Paste it into the example app

## Troubleshooting

### Common Issues

**"Initialization failed"**
- Check that your API key is correct
- Ensure you have an internet connection

**"No network calls being made"**
- Verify that the SDK is initialized with the intended account's public API key
- Check your Klaviyo account dashboard for incoming data
- Check SDK logging and the device console for more details

**"Push notifications not working"**
- Use real APNs/FCM delivery to verify background behavior. Simulated notifications do not exercise every delivery path
- Ensure notification permissions are granted
- Check that push certificates are configured in Klaviyo

**Buttons are disabled**
- Make sure the SDK is initialized first
- Check the status message for any error details

## Code Structure

The example app demonstrates:

- **Dynamic API Key Input**: User can enter their own API key
- **Initialization Flow**: Proper SDK setup with error handling
- **Event Listeners**: How to listen for push notification events
- **Error Handling**: Comprehensive error handling for all operations
- **UI Best Practices**: Clean, organized interface with status feedback

## Next Steps

Once you've tested the example app:

1. **Integrate into Your App**: Copy the initialization and setup code
2. **Customize Events**: Modify the event tracking for your specific use cases
3. **Handle Push Opens**: Implement your own push notification open handling
4. **Configure Forms**: Set up in-app forms in your Klaviyo dashboard

For more detailed implementation guidance, see the main [SDK README](../README.md).
