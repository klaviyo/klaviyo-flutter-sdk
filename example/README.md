# Klaviyo Flutter SDK Example App

This example app demonstrates how to use the Klaviyo Flutter SDK with a user-friendly interface for testing all SDK features.

## Getting Started

### 1. API Key Setup

When you first launch the app, you'll see an **API Key input field** at the top:

- **Default Value**: The field is pre-filled with `Xr5bFG` (a demo API key for testing)
- **Your API Key**: Replace this with your actual Klaviyo API key from your account
- **Where to Find**: Log into your Klaviyo account → Settings → API Keys → Public API Key

### 2. Initialize the SDK

1. Enter your API key in the text field
2. Tap **"Initialize SDK"** button
3. Wait for the status to show "Initialized successfully"
4. Once initialized, you can use all the SDK features

### 3. Reset and Change API Key

- If you need to test with a different API key, tap the **"Reset"** button
- This will allow you to enter a new API key and reinitialize

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
- **Register for Push**: Request notification permissions and register for push notifications
- **Get Push Token Info**: Retrieve detailed information about the push token
- **Get Push Token**: Get the raw push token string

### 🎯 In-App Forms
- **Register for Forms**: Enable in-app forms that will show automatically based on Klaviyo targeting

### ⚙️ Configuration
- **Set Log Level**: Change the verbosity of SDK logging

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

1. Add to `ios/Podfile` (before `flutter_install_all_ios_pods`):
   ```ruby
   ENV['KLAVIYO_INCLUDE_LOCATION'] = 'true'
   ```

2. Add location permission descriptions to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We use your location for geofencing features.</string>

   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>We need background location for geofence monitoring.</string>
   ```

3. Rebuild:
   ```bash
   cd ios && rm -rf Pods Podfile.lock && pod install && cd .. && flutter clean && flutter run
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

#### iOS Pod Verification

```bash
# Default (should NOT include location pod)
cd ios && pod install
pod list | grep KlaviyoLocation
# Expected: No output (pod not installed)

# With ENV['KLAVIYO_INCLUDE_LOCATION'] = 'true'
# (Add ENV line to Podfile first)
cd ios && rm -rf Pods Podfile.lock && pod install
pod list | grep KlaviyoLocation
# Expected: Shows KlaviyoLocation with version number
```

## Push Notification Testing

To test push notifications:

1. **Use a Real Device**: Push notifications don't work in the iOS Simulator
2. **Register for Push**: Tap "Register for Push" and allow permissions
3. **Send a Test Push**: Use your Klaviyo dashboard to send a test push notification
4. **Tap the Notification**: When you receive it, tap to open
5. **Check the Status**: The app will show "Push notification opened!" with the data

## API Key Information

### Demo API Key (`Xr5bFG`)
- This is a test API key provided by Klaviyo for examples
- It allows the SDK to initialize but may not send real data
- Perfect for testing the app functionality

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
- Try using the demo API key `Xr5bFG` first

**"No network calls being made"**
- Verify you're using a real API key (not the demo one)
- Check your Klaviyo account dashboard for incoming data
- Enable debug logging to see more details

**"Push notifications not working"**
- Must use a physical device (not simulator)
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

For more detailed implementation guidance, see the main SDK documentation and the `PUSH_NOTIFICATION_TRACKING_GUIDE.md`.
