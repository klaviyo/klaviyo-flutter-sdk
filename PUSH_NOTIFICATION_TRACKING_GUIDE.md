# Push Notification Open Tracking Guide

This guide explains how push notification open tracking is implemented in the Klaviyo Flutter SDK.

## Overview

The Klaviyo Flutter SDK now includes comprehensive push notification open tracking that automatically handles:

1. **Push Token Registration** - Automatic APNs token registration and sharing with Klaviyo
2. **Push Notification Opens** - Automatic tracking when users tap on push notifications
3. **Cross-Platform Events** - Unified event handling between native iOS/Android and Flutter

## Implementation Details

### iOS Implementation

#### AppDelegate Setup

The `AppDelegate.swift` includes:

```swift
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Klaviyo SDK
    KlaviyoSDK().initialize(with: "YOUR_API_KEY")
    
    // Set up notification center delegate for push open tracking
    UNUserNotificationCenter.current().delegate = self
    
    // Request push notification permissions
    requestPushNotificationPermissions()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
  
  // Called when user taps on a notification (app in background/terminated)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Notify the Flutter plugin about the push notification open
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onPushNotificationOpened", arguments: ["userInfo": userInfo])
    }
    
    // Let Klaviyo SDK handle the push open tracking
    let handled = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: completionHandler)
    
    if handled {
      print("✅ Klaviyo handled push notification open")
    } else {
      print("ℹ️ Non-Klaviyo push notification opened")
      completionHandler()
    }
  }
  
  // Called when a notification is received while app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show the notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
```

#### iOS Plugin Integration

The iOS plugin (`KlaviyoFlutterSdkPlugin.swift`) includes:

```swift
case "onPushNotificationOpened":
  // Called from AppDelegate when a push notification is opened
  guard let args = call.arguments as? [String: Any],
    let userInfo = args["userInfo"] as? [String: Any]
  else {
    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid notification data", details: nil))
    return
  }
  
  // Notify Flutter side via event sink if available
  if let eventSink = self.eventSink {
    eventSink([
      "type": "push_notification_opened",
      "data": userInfo
    ])
  }
  result(nil)
```

### Flutter Integration

#### Native Wrapper

The `KlaviyoNativeWrapper` handles events from the native side:

```dart
void _handleNativeEvent(dynamic event) {
  try {
    final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
    final String eventType = eventData['type'] as String? ?? '';

    switch (eventType) {
      case 'push_notification_received':
      case 'push_notification_opened':
        _pushNotificationController.add(eventData);
        break;
      // ... other cases
    }
  } catch (e) {
    print('Error handling native event: $e');
  }
}
```

#### Main SDK

The main `KlaviyoSDK` exposes push notification events:

```dart
/// Get push notification events stream
Stream<Map<String, dynamic>> get onPushNotification =>
    _nativeWrapper.onPushNotification;

void _setupNativeEventListeners() {
  // Listen for push notification events from native SDK
  _nativeWrapper.onPushNotification.listen((eventData) {
    final eventType = eventData['type'] as String? ?? '';
    
    if (eventType == 'push_notification_opened') {
      final userInfo = eventData['data'] as Map<String, dynamic>? ?? {};
      _logger.info('Push notification opened with data: $userInfo');
      // The event is automatically forwarded via the stream
    }
  });
}
```

## Usage in Your App

### 1. Initialize with Push Notification Listeners

```dart
class _MyAppState extends State<MyApp> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();

  @override
  void initState() {
    super.initState();
    _initializeKlaviyo();
  }

  Future<void> _initializeKlaviyo() async {
    final apiKey = _apiKeyController.text.trim();
    
    if (apiKey.isEmpty) {
      setState(() {
        _status = 'Please enter a valid API key';
      });
      return;
    }

    await _klaviyo.initialize(
      apiKey: apiKey, // Use user-provided API key
      logLevel: KlaviyoLogLevel.debug,
      environment: PushEnvironment.production,
    );

    // Set up push notification listeners
    _setupPushNotificationListeners();
  }

  void _setupPushNotificationListeners() {
    // Listen for push notification opens
    _klaviyo.onPushNotification.listen((eventData) {
      final eventType = eventData['type'] as String? ?? '';
      
      if (eventType == 'push_notification_opened') {
        final userInfo = eventData['data'] as Map<String, dynamic>? ?? {};
        print('🎯 Push notification opened: $userInfo');
        
        // Handle the push notification open
        _handlePushNotificationOpen(userInfo);
      }
    });
  }

  void _handlePushNotificationOpen(Map<String, dynamic> userInfo) {
    // Extract relevant data from the push notification
    final String? deepLink = userInfo['deep_link'] as String?;
    final String? campaignId = userInfo['campaign_id'] as String?;
    
    // Navigate to specific screen or perform action based on push content
    if (deepLink != null) {
      // Navigate to deep link
      Navigator.pushNamed(context, deepLink);
    }
    
    // Track custom event for analytics
    _klaviyo.track('Push Notification Opened', {
      'campaign_id': campaignId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

### 2. Register for Push Notifications

```dart
Future<void> _registerForPushNotifications() async {
  try {
    // Register for push notifications (will request permission on iOS)
    await _klaviyo.registerForPushNotifications();
    print('✅ Registered for push notifications');
  } catch (e) {
    print('❌ Failed to register for push notifications: $e');
  }
}
```

## Event Data Structure

When a push notification is opened, the event data structure is:

```dart
{
  "type": "push_notification_opened",
  "data": {
    // Native push notification userInfo dictionary
    "aps": {
      "alert": "Your notification message",
      "badge": 1,
      "sound": "default"
    },
    // Klaviyo-specific data
    "campaign_id": "abc123",
    "deep_link": "/product/123",
    // Any custom data you included in the push
    "custom_field": "custom_value"
  }
}
```

## Key Features

### ✅ What's Implemented

1. **Automatic Push Open Tracking** - Klaviyo SDK automatically tracks when users open push notifications
2. **Cross-Platform Events** - Events are forwarded from native to Flutter for custom handling
3. **Permission Handling** - Automatic request for push notification permissions on iOS
4. **Token Management** - Automatic APNs token registration and sharing with Klaviyo
5. **Foreground Notifications** - Notifications are shown even when the app is in the foreground
6. **Error Handling** - Comprehensive error handling and logging

### 🔧 Configuration Options

- **Environment**: Set to `PushEnvironment.development` or `PushEnvironment.production`
- **Log Level**: Control logging verbosity with `KlaviyoLogLevel`
- **Custom Handling**: Listen to the `onPushNotification` stream for custom logic

### 📝 Best Practices

1. **Always listen for events** after SDK initialization
2. **Handle deep links** appropriately based on your app's navigation structure
3. **Track custom events** for additional analytics when push notifications are opened
4. **Test thoroughly** with both development and production push certificates
5. **Handle errors gracefully** and provide fallback behavior

## Testing

To test push notification open tracking:

1. **Build and install** your app on a physical device (push notifications don't work in simulator)
2. **Send a push notification** through Klaviyo's dashboard or API
3. **Tap the notification** when it appears
4. **Check the logs** for the tracking events
5. **Verify in Klaviyo** that the open event was recorded

## Troubleshooting

### Common Issues

1. **No events received**: Ensure the SDK is properly initialized and event listeners are set up
2. **Permission denied**: Check that push notification permissions are granted
3. **Token not set**: Verify that `registerForPushNotifications()` is called and completes successfully
4. **Events not tracking**: Ensure you're using a valid Klaviyo API key and the profile is set

### Debug Steps

1. Enable debug logging: `KlaviyoLogLevel.debug`
2. Check native logs in Xcode console
3. Verify push notification payload structure
4. Test with a simple push notification first
5. Ensure the app is properly configured in Klaviyo dashboard

## Migration from Previous Versions

If you're upgrading from a previous version:

1. **Remove Firebase dependencies** (if you were using them for push notifications)
2. **Update AppDelegate** to include the new UNUserNotificationCenterDelegate methods
3. **Set up event listeners** in your Flutter code
4. **Test thoroughly** to ensure push notifications still work as expected

This implementation provides a robust, native-first approach to push notification tracking that leverages the full power of the Klaviyo iOS SDK while providing a clean Flutter interface. 