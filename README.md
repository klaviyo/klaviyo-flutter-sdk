# Klaviyo Flutter SDK

A Flutter plugin that wraps the native [Klaviyo iOS](https://github.com/klaviyo/klaviyo-swift-sdk) and [Android](https://github.com/klaviyo/klaviyo-android-sdk) SDKs, enabling you to integrate Klaviyo's marketing automation features into your Flutter apps.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Initialization](#initialization)
- [Platform Setup](#platform-setup)
  - [iOS](#ios-setup)
  - [Android](#android-setup)
- [Profile Management](#profile-management)
- [Event Tracking](#event-tracking)
- [Subscriptions](#subscriptions)
- [Push Notifications](#push-notifications)
  - [Prerequisites](#prerequisites)
  - [Requesting Permissions](#requesting-notification-permissions)
  - [Token Collection](#token-collection)
  - [Handling Push Opens](#handling-push-notification-opens)
  - [Action Buttons](#action-buttons)
  - [Rich Push](#rich-push)
  - [Badge Count (iOS)](#badge-count-ios-only)
- [In-App Forms](#in-app-forms)
  - [Monitoring Form Lifecycle Events](#monitoring-form-lifecycle-events)
- [Deep Linking](#deep-linking)
- [Geofencing](#geofencing)
- [Optional Module Configuration](#optional-module-configuration)
  - [Enabling Geofencing](#enabling-geofencing)
  - [Disabling In-App Forms](#disabling-in-app-forms)
- [Profile Reset (Logout)](#profile-reset-logout)
- [SDK Logging](#sdk-logging)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Features

- **Profile Management** — Set user profiles, emails, phone numbers, and custom properties
- **Event Tracking** — Track custom events and user interactions
- **Push Notifications** — Register for and handle push notifications with automatic token handling
- **In-App Forms** — Display and manage in-app forms for lead capture
- **Deep Linking** — Handle custom URL schemes, universal links, and Klaviyo tracking links
- **Geofencing** — Observe geofences for location-based event tracking

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | 3.27.0+        |
| Dart     | 3.x            |
| iOS      | 15.0+          |
| Android `minSdkVersion` | 23+ |
| Android `compileSdkVersion` | 35+ (tracks `flutter.compileSdkVersion`) |
| Kotlin   | 1.8.0+         |

## Installation

Add `klaviyo_flutter_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  klaviyo_flutter_sdk: ^0.3.0
```

A complete working example is available in the [`example/`](example/) directory.

## Initialization

```dart
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await KlaviyoSDK().initialize(
    apiKey: 'YOUR_KLAVIYO_PUBLIC_API_KEY',
  );

  runApp(MyApp());
}
```

## Platform Setup

The Flutter plugin depends on the native Swift and Android SDKs, which are automatically installed by the plugin. On Android, required permissions are also automatically added via manifest merging.

The sections below cover required native configuration for push notification handling.

### iOS Setup

**1. Install Pods**

```bash
cd ios && pod install
```

**2. Enable Capabilities**

Open your project in Xcode (`ios/Runner.xcworkspace`), select the **Runner** target, go to **Signing & Capabilities**, and add:
- **Push Notifications** (Required for APNs push notifications)
- **Background Modes** → check **Remote notifications** (Required for silent push updates)

**3. AppDelegate Setup**

To display push notifications in the foreground and track "Open" events, update your `ios/Runner/AppDelegate.swift`:

1. Import the plugin module: `import klaviyo_flutter_sdk`
2. Set the notification delegate: Assign `UNUserNotificationCenter.current().delegate = self` in `application(_:didFinishLaunchingWithOptions:)`
3. Implement (or update) the `userNotificationCenter` methods to forward events to the Klaviyo SDK (see example code below)

> **Note on Push Token Handling:** The plugin automatically intercepts `didRegisterForRemoteNotificationsWithDeviceToken` to capture the APNs token. If you override this method (e.g., for another push provider), call `super`:
>
> ```swift
> override func application(
>     _ application: UIApplication,
>     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
> ) {
>     super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
>     // Your custom token handling here
> }
> ```

**Full AppDelegate example:**

```swift
import UIKit
import Flutter
import klaviyo_flutter_sdk

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // ... Your existing setup code ...

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle foreground notifications
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when the app is open
        completionHandler([.banner, .sound, .badge])

        // ... Your custom logic (if any) ...
    }

    // Forward tap events to Klaviyo
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

    // Handle silent push notifications (optional)
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // This method fires for both pure silent pushes (content-available: 1, no alert)
        // and standard pushes that include content-available. Only forward pure silent
        // pushes to the Klaviyo plugin — standard pushes are handled by willPresent/didReceive.
        // Per the APNs spec, title/body are nested inside alert, so checking alert covers
        // all visible-content cases.
        let apsPayload = userInfo["aps"] as? [String: Any]
        let hasVisibleContent = apsPayload?["alert"] != nil
        if !hasVisibleContent {
            KlaviyoFlutterSdkPlugin.shared.handleSilentPush(userInfo: userInfo)
        }

        // ... Your custom logic (if any) ...

        // You MUST call the completion handler within ~30 seconds.
        // Failing to do so will cause iOS to throttle or stop delivering
        // silent push notifications to your app.
        completionHandler(.newData)
    }
}
```

> **Note on automatic tracking:** Keep the manual `AppDelegate` wiring shown above. The native iOS SDK offers an opt-in automatic push-open tracking mode (`klaviyo_automatic_push_open_tracking` in `Info.plist`), but it does **not** replace this wiring in a Flutter app: the Dart `push_notification_opened` stream is emitted by the plugin, which only learns about the tap through the `userNotificationCenter(_:didReceive:...)` code above. Enabling the flag is safe rather than harmful — the native SDK still tracks the "Opened Push" event and resolves the notification's deep link/web URL — but it is redundant here, since the plugin's own Dart-facing events still depend on the manual wiring. See the native [iOS docs](https://github.com/klaviyo/klaviyo-swift-sdk#tracking-open-events) for that behavior.

### Android Setup

**1. MainActivity Setup**

To track push notification opens, handle intents in your `MainActivity` (at `android/app/src/main/kotlin/.../MainActivity.kt`). See the [example MainActivity.kt](example/android/app/src/main/kotlin/com/klaviyo/flutterexample/MainActivity.kt) for reference.

```kotlin
import android.content.Intent
import android.os.Bundle
import com.klaviyo.analytics.Klaviyo
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle notification intent on cold start
        intent?.let { Klaviyo.handlePush(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle notification intent on warm start
        Klaviyo.handlePush(intent)
    }
}
```

> **Note on automatic tracking:** Keep the manual `AppDelegate`/`MainActivity` wiring shown above. The native SDKs offer an opt-in automatic push-open tracking mode, but it does **not** replace this wiring in a Flutter app: the Dart `push_notification_opened` stream is emitted by the plugin, which only learns about the tap through the code above. Enabling it is safe rather than harmful — both native SDKs deduplicate the open and forward the tap onward, so your handlers still run — but it is redundant here. See the native [iOS](https://github.com/klaviyo/klaviyo-swift-sdk#tracking-open-events) and [Android](https://github.com/klaviyo/klaviyo-android-sdk#Tracking-Open-Events) docs for that behavior.

**2. KlaviyoPushService Declaration**

The plugin auto-registers `KlaviyoFlutterPushService` (a subclass of `KlaviyoPushService`) for `com.google.firebase.MESSAGING_EVENT`. The subclass invokes `super.onMessageReceived(message)` so all standard Klaviyo push handling still runs, and additionally forwards Klaviyo silent pushes to the Dart event stream. **No host-app manifest changes are required.**

Android delivers `MESSAGING_EVENT` to exactly one service, so the plugin also removes the native SDK's own `KlaviyoPushService` from the merged manifest via `tools:node="remove"`. Without that, the base class can win the intent and the subclass never runs — standard push keeps working, but silent pushes never reach Dart. Nothing is lost by removing it, since `KlaviyoFlutterPushService` extends it and calls `super`.

> **Migrating from earlier versions**: if your app previously declared `<service android:name="com.klaviyo.pushFcm.KlaviyoPushService">` for `MESSAGING_EVENT`, **remove it**. A declaration in your own manifest takes priority over everything the plugin contributes, so it would win the intent and suppress silent push forwarding. If you need custom FCM handling, subclass `KlaviyoFlutterPushService` rather than registering a second service.

## Profile Management

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

## Event Tracking

```dart
// Track a predefined event
final openedAppEvent = KlaviyoEvent(
  name: EventMetric.openedApp,
  properties: {
    'source': 'home_screen',
  },
);
await KlaviyoSDK().createEvent(openedAppEvent);
```

```dart
// Track a custom event
final customEvent = KlaviyoEvent.custom(
  metric: 'User Completed Tutorial',
  properties: {
    'tutorial_id': 'intro_v2',
    'completion_time_seconds': 245,
  },
);
await KlaviyoSDK().createEvent(customEvent);
```

```dart
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
await KlaviyoSDK().createEvent(purchaseEvent);
```

## Subscriptions

Subscribe the current profile to a Klaviyo list and record its consent. Set the profile's email
and/or phone number **before** subscribing — a request whose channel has no matching identifier on
the profile is dropped with a warning from the native SDK.

Push subscriptions are not created through this API. See [Push Notifications](#push-notifications).

```dart
// Request specific consent per channel
await KlaviyoSDK().createSubscription(
  KlaviyoSubscription(
    listId: 'ABC123',
    channels: const KlaviyoSubscriptionChannels(
      email: {EmailConsent.marketing, EmailConsent.openTracking},
      sms: {MessagingConsent.marketing},
    ),
  ),
);
```

```dart
// Attach a signup source label, stored as the consent record's $source
await KlaviyoSDK().createSubscription(
  KlaviyoSubscription(
    listId: 'ABC123',
    channels: const KlaviyoSubscriptionChannels(
      sms: {MessagingConsent.marketing},
      whatsapp: {MessagingConsent.transactional},
    ),
    customSource: 'Checkout screen',
  ),
);
```

```dart
// Request marketing consent on every channel the profile has an identifier for
await KlaviyoSDK().createSubscription(
  KlaviyoSubscription.allAvailableMarketing(listId: 'ABC123'),
);
```

Each channel accepts only the consent types the API supports for it: email takes `marketing` and
`openTracking`, while SMS and WhatsApp take `marketing` and `transactional`. Omitting a channel
leaves it untouched.

## Push Notifications

### Prerequisites

**Platform-specific setup:**
- Complete the [iOS Setup](#ios-setup) and [Android Setup](#android-setup) sections above
- For additional context, see the native push documentation: [Android](https://github.com/klaviyo/klaviyo-android-sdk#push-notifications) | [iOS](https://github.com/klaviyo/klaviyo-swift-sdk#push-notifications)

**Key requirements:**
- Firebase project configured (for both platforms)
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) added to your project
- Push notifications configured in your [Klaviyo account settings](https://help.klaviyo.com/hc/en-us/articles/14750928993307)

### Requesting Notification Permissions

Permission can be managed from Flutter code or platform-specific native code. Either approach informs the Klaviyo SDK of the permission change. For Flutter-side handling, use a third-party package such as [firebase_messaging](https://pub.dev/packages/firebase_messaging) or [permission_handler](https://pub.dev/packages/permission_handler).

### Token Collection

The Klaviyo SDK needs to register the device's push token. Choose one of the following approaches:

#### Automatic Token Forwarding

**This plugin forwards the push token to Klaviyo automatically on both platforms.** No native code is
required in your app to make token registration work:

- **Android** — the plugin auto-registers `KlaviyoFlutterPushService` (a `FirebaseMessagingService`,
  subclassing the native SDK's `KlaviyoPushService`) via manifest merge, which forwards the FCM
  token to Klaviyo.
- **iOS** — this plugin registers itself as an application delegate and intercepts
  `didRegisterForRemoteNotificationsWithDeviceToken`. If you override that method in your
  `AppDelegate`, call `super` or the token will not reach Klaviyo — see [iOS Setup](#ios-setup).

On iOS the token is only delivered once your app registers for remote notifications — via
`registerForPushNotifications()` (Option B) or a package such as `firebase_messaging` (Option A).

Manual token management (Option A) remains the recommended baseline: it works identically on both
platforms and gives you control over the token pipeline, such as forwarding the token to multiple push
providers. Setting the token yourself alongside automatic forwarding is expected and needs no
coordination — the native SDK only sends a request when the push state actually changes, so a
redundant registration costs nothing.

<details>
<summary><strong>Advanced:</strong> native SDK configuration flags</summary>

Both native SDKs expose an `automatic_push_token_forwarding` flag. Most Flutter apps should not set
either one, and a future release may replace them with a cross-platform control.

- **iOS** — the `klaviyo_automatic_push_token_forwarding` `Info.plist` key gates only the native SDK's
  app-delegate swizzling. It does **not** disable this plugin's forwarding.
- **Android** — the `com.klaviyo.push.automatic_push_token_forwarding` manifest `meta-data` key is
  three-valued, because leaving it unset is different from setting it to `false`:

  | Value | Behavior |
  |---|---|
  | **not set** (default) | `KlaviyoFlutterPushService` forwards a token whenever FCM delivers one — this plugin's existing automatic behavior, unaffected. |
  | **`true`** | Additionally fetches and registers the current token at `Klaviyo.initialize()` and on each foreground. |
  | **`false`** | Disables forwarding entirely — set this only if you register the token yourself, since Klaviyo otherwise keeps whatever token it last stored, which goes stale once FCM rotates it. |

For the underlying native behavior, see the native
[Android](https://github.com/klaviyo/klaviyo-android-sdk#push-notifications) and
[iOS](https://github.com/klaviyo/klaviyo-swift-sdk#push-notifications) push documentation.

</details>

#### Option A: Manual Token Management with Firebase Messaging (Recommended)

Best if you already use `firebase_messaging`, or if you need more control over token handling (such as to send the token to multiple push providers).

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';

final _logger = Logger('MyApp');

// Get token from Firebase and pass to Klaviyo
if (Platform.isIOS) {
  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

  if (apnsToken != null) {
    await KlaviyoSDK().setPushToken(apnsToken);
    _logger.info('Sent APNs token to Klaviyo');
  } else {
    _logger.warning('APNs token was null. Waiting for refresh...');
  }
} else if (Platform.isAndroid) {
  String? fcmToken = await FirebaseMessaging.instance.getToken();

  if (fcmToken != null) {
    await KlaviyoSDK().setPushToken(fcmToken);
    _logger.info('Sent FCM token to Klaviyo');
  }
}

// Listen for Token Refreshes (Important for long-running apps)
// Note: On iOS, this stream returns the FCM token, not APNs.
// Native APNs token changes are rare, but for Android this is crucial.
if (Platform.isAndroid) {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    KlaviyoSDK().setPushToken(newToken);
  });
// On iOS, if the APNs token changes, the OS usually relaunches the app
// or triggers distinct native callbacks.
}
```

#### Option B: Built-in Registration

The simplest approach — the SDK automatically fetches the push token without requiring `firebase_messaging` as a direct dependency:

```dart
// iOS: Triggers APNs registration and forwards token to Klaviyo
// Android: Fetches the FCM token and registers it with Klaviyo
await KlaviyoSDK().registerForPushNotifications();
```

For visibility into push token events, subscribe to the `onPushNotification` stream:
```dart
// Listen for token events
KlaviyoSDK().onPushNotification.listen((event) {
  switch (event['type']) {
    case 'push_token_received':
      final token = event['data']['token'];
      _logger.info('Token received: $token');
      break;
    case 'push_token_error':
      final error = event['data']['error'];
      _logger.warning('Token error: $error');
      break;
  }
});
```

### Handling Push Notification Opens

```dart
KlaviyoSDK().onPushNotification.listen((event) {
  if (event['type'] == 'push_notification_opened') {
    _logger.info('Notification opened: ${event['data']}');
  }
});
```

> **Why this stream exists alongside native tracking:** The native SDK's own open-tracking (automatic or via the manual `AppDelegate`/`MainActivity` wiring above) reports the "Opened Push" event to Klaviyo's backend for analytics and flow triggers — it has no effect on your Flutter app's runtime behavior. This Dart stream is the separate, app-facing signal: it's how your Flutter code learns a notification was tapped, with the payload, so it can react (navigate, update state, log to your own analytics). Native tracking and this stream serve different consumers — Klaviyo's backend vs. your app — so both exist independently.

#### Identifying Klaviyo Notifications

Use the `isKlaviyoNotification` extension to check whether a push notification payload originated from Klaviyo:

```dart
void handlePushPayload(Map<String, dynamic> payload) {
  if (payload.isKlaviyoNotification) {
    // This is a Klaviyo notification
  }
}
```

### Silent Push

Silent push notifications (`content-available: 1`) deliver data to your app in the background without showing a banner. They are commonly used to prefetch content, sync state, or trigger background tasks.

> **iOS requirement**: Enable "Remote notifications" under **Background Modes** in Xcode (covered in [iOS Setup](#ios-setup)).

#### iOS

iOS delivers silent pushes via `didReceiveRemoteNotification:fetchCompletionHandler:` in your `AppDelegate.swift`. The setup in [iOS Setup](#ios-setup) already handles this — it differentiates pure silent pushes from standard pushes that carry `content-available` and forwards only the former to the Klaviyo plugin.

#### Android

The plugin's manifest already contributes `KlaviyoFlutterPushService`, an FCM service that forwards Klaviyo silent pushes to the Dart event stream. No host configuration is required — silent push events flow to your Dart listener automatically.

#### Delivery Guarantees

Your listener fires for every Klaviyo silent push, with the full payload and its JSON object values decoded to maps on both platforms. Delivery needs a live Flutter engine: foreground **and backgrounded** apps both receive events, a terminated one does not. Nothing is cached or replayed on a later launch, matching both native SDKs — a missed push is gone.

> **Known limitation (Android)**: while your app isn't running — swiped away, force-stopped, or evicted — there's no Flutter engine to receive silent pushes, and nothing is queued for the next launch. The native Android SDK has no such gap, and we plan to close it. Until then, either subclass `KlaviyoFlutterPushService` and handle it in Kotlin, or use [`firebase_messaging`](https://pub.dev/packages/firebase_messaging)'s `onBackgroundMessage`, which runs its own engine and coexists with this plugin — it receives messages via a broadcast receiver rather than the `MESSAGING_EVENT` service. It also fires while your app is running, so guard against handling a push twice. iOS is unaffected: the system relaunches your app, so the `AppDelegate` path still runs.

#### Dart-Side Listener

Subscribe to `onPushNotification` to react to silent push events in Flutter:

```dart
KlaviyoSDK().onPushNotification.listen((event) {
  if (event['type'] == 'silent_push_received') {
    final payload = Map<String, dynamic>.from(event['data'] as Map);
    // Perform background work: refresh content, sync state, etc.
  }
});
```

> **Note**: This event fires only for pure silent pushes (no visible content). Standard notifications that include `content-available` are handled by `willPresent`/`didReceive` and will not trigger this event.

### Action Buttons

Klaviyo push messages can include up to three tappable action buttons, each with a custom label and either a deep link or an open-app action. Buttons are configured in the Klaviyo dashboard — no Flutter or native integration changes are required, and tapping a button dismisses the notification automatically.

If a button is configured with a deep link, your existing [Deep Linking](#deep-linking) setup handles navigation when the user taps it.

### Rich Push

[Rich Push](https://help.klaviyo.com/hc/en-us/articles/16917302437275) lets you add images and videos (iOS only) to push notifications.

- **Android**: No additional setup needed. Refer to the [Android SDK documentation](https://github.com/klaviyo/klaviyo-android-sdk#Rich-Push) for more details.
- **iOS**: Requires a notification service extension. Follow the CocoaPods setup steps in the [iOS SDK installation guide](https://github.com/klaviyo/klaviyo-swift-sdk/blob/master/README.md#installation), then see the [Rich Push documentation](https://github.com/klaviyo/klaviyo-swift-sdk#rich-push-images--videos).

### Badge Count (iOS Only)

Klaviyo supports setting or incrementing the badge count on iOS push notifications. This requires a notification service extension and app group — see the [Swift SDK installation instructions](https://github.com/klaviyo/klaviyo-swift-sdk?tab=readme-ov-file#installation) and [badge count documentation](https://github.com/klaviyo/klaviyo-swift-sdk?tab=readme-ov-file#badge-count).

Android handles badge counts automatically.

## In-App Forms

In-app forms — these are configured in the Klaviyo dashboard and rendered automatically by the SDK. No Flutter or native integration changes are required to support new presentation styles.

```dart
// Register with default session timeout (1 hour)
await KlaviyoSDK().registerForInAppForms();
```
```dart
// Register with a custom session timeout
final config = InAppFormConfig(
  sessionTimeoutDuration: Duration(minutes: 30),
);
await KlaviyoSDK().registerForInAppForms(configuration: config);
```
```dart
// Register with infinite session timeout (no timeout)
final infiniteConfig = InAppFormConfig.infinite();
await KlaviyoSDK().registerForInAppForms(configuration: infiniteConfig);
```
```dart
// Unregister from in-app forms
await KlaviyoSDK().unregisterFromInAppForms();
```

The `sessionTimeoutDuration` controls how long forms remain eligible to display after app backgrounding. For more details, see the native SDK documentation: [Android](https://github.com/klaviyo/klaviyo-android-sdk#in-app-messages) | [iOS](https://github.com/klaviyo/klaviyo-swift-sdk#in-app-messages)

### Monitoring Form Lifecycle Events

> Available in Flutter SDK 0.2.0 and higher. For the equivalent API on other platforms, see the [Android SDK](https://github.com/klaviyo/klaviyo-android-sdk#in-app-messages) and [iOS SDK](https://github.com/klaviyo/klaviyo-swift-sdk#in-app-messages) documentation.

Subscribe to `onFormLifecycleEvent` to observe in-app form lifecycle changes. This is useful for forwarding form engagement data to a third-party analytics platform such as Amplitude, Segment, or Mixpanel, or for triggering app-specific logic when a form is shown or dismissed.

Events are delivered on the main isolate (Flutter's UI thread) via the native `EventChannel`, in the same order they are emitted by the native SDK.

```dart
import 'dart:async';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

final _logger = Logger('MyApp');

// Subscribe to form lifecycle events
final StreamSubscription<FormLifecycleEvent> subscription =
    KlaviyoSDK().onFormLifecycleEvent.listen((event) {
  switch (event) {
    case FormShown():
      _logger.info('Form shown — id: ${event.formId}, name: ${event.formName}');
    case FormDismissed():
      _logger.info('Form dismissed — id: ${event.formId}, name: ${event.formName}');
    case FormCtaClicked():
      _logger.info(
        'CTA tapped — id: ${event.formId}, name: ${event.formName}, '
        'button: "${event.buttonLabel}", url: ${event.deepLinkUrl}',
      );
  }
});

// Cancel when no longer needed (e.g. in dispose())
subscription.cancel();
```

**Field reference:**

| Field | Type | Subtypes | Notes |
|-------|------|----------|-------|
| `formId` | `String` | All | Unique identifier for the form |
| `formName` | `String` | All | Display name configured in Klaviyo dashboard |
| `buttonLabel` | `String` | `FormCtaClicked` only | Label of the tapped CTA button |
| `deepLinkUrl` | `String` | `FormCtaClicked` only | Deep link URL configured for the CTA |

## Push Action Events

Subscribe to `onPushAction` to observe taps on Klaviyo pushes that carry an **Open External URL** (`open_url`) action or **action buttons**. Events are typed via the sealed `KlaviyoPushAction` class, so Dart pattern matching is exhaustive.

This stream is **observation-only**: the native SDK still performs all navigation (opening the URL, launching the app, or routing the deep link) with no integration changes required — as described in [Action Buttons](#action-buttons). `onPushAction` simply lets your app react in parallel (analytics, in-app routing, UI updates).

```dart
import 'dart:async';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

final _logger = Logger('MyApp');

final StreamSubscription<KlaviyoPushAction> subscription =
    KlaviyoSDK().onPushAction.listen((action) {
  switch (action) {
    case OpenWebUrl():
      _logger.info('Open external URL: ${action.url}');
    case ActionButtonTapped():
      _logger.info(
        'Action button "${action.label}" (${action.action}) — '
        'id: ${action.buttonId}, url: ${action.url}',
      );
  }
});

// Cancel when no longer needed (e.g. in dispose())
subscription.cancel();
```

**Field reference:**

| Field | Type | Subtypes | Notes |
|-------|------|----------|-------|
| `url` | `String` | `OpenWebUrl` | The external URL. May be `http(s)` or a special scheme such as `mailto:`, `tel:`, `sms:` |
| `buttonId` | `String` | `ActionButtonTapped` | Identifier of the tapped action button |
| `label` | `String` | `ActionButtonTapped` | Display label of the tapped button |
| `action` | `String` | `ActionButtonTapped` | One of `open_app`, `deep_link`, `open_url` |
| `url` | `String?` | `ActionButtonTapped` | URL for `deep_link` / `open_url` buttons; `null` for `open_app` |

> **Platform behavior:** The native SDK still performs the actual navigation (opening the URL or launching the app); these events let your app react in parallel. On **iOS**, both body `open_url` taps and action-button taps surface. On **Android**, `open_url` is dispatched to an external handler by the native SDK and does **not** reach the app, so only `deep_link` / `open_app` action-button taps surface on Android.

## Deep Linking

Klaviyo supports [Deep Links](https://help.klaviyo.com/hc/en-us/articles/14750403974043) for tracking link clicks and navigating to specific content within your app. This works with push notifications, in-app messages, and Klaviyo tracking links.

### Prerequisites

1. Set up deep linking in your Flutter app using a routing package:
   - [go_router](https://pub.dev/packages/go_router) (recommended by Flutter team)
   - [app_links](https://pub.dev/packages/app_links) or [uni_links](https://pub.dev/packages/uni_links)
   - Flutter's built-in `WidgetsBindingObserver`

2. Configure platform-specific deep linking (see below).

### iOS Deep Linking

**Custom URL Schemes** (e.g., `myapp://product/123`)

Follow steps 1 & 2 ("Register the URL scheme" and "Whitelist your URL scheme") under the [Handling URL Schemes](https://github.com/klaviyo/klaviyo-swift-sdk#handling-url-schemes) section of the Swift SDK README.

> `FlutterAppDelegate` handles `application(_:open:options:)` and forwards custom URL scheme deep links to Flutter automatically. No additional native code is required.

**Klaviyo Universal Tracking Links** (e.g., `https://trk.yourdomain.com/u/abc123`)

Follow steps 1 & 2 ("Configure Universal Links in your Klaviyo account" and "Add the Associated Domains Entitlement") under the [Handling Universal Links](https://github.com/klaviyo/klaviyo-swift-sdk?tab=readme-ov-file#handling-universal-links) section of the Swift SDK README.

> `FlutterAppDelegate` implements `application(_:continue:restorationHandler:)` and forwards universal links to Flutter automatically.

Once universal links are arriving in your Flutter app, call handleUniversalTrackingLink from your router to let the Klaviyo SDK resolve tracking URLs.
See the [go_router integration](https://github.com/klaviyo/klaviyo-flutter-sdk#Handling-Tracking-Links-with-go_router) section for an example.

### Android Deep Linking

The [example AndroidManifest.xml](example/android/app/src/main/AndroidManifest.xml#L31-L60) demonstrates all three types of deep links:

**Custom URL Schemes** (e.g., `myapp://product/123`)

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

**App Links** (e.g., `https://yourdomain.com/product/123`)

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" />
    <data android:host="yourdomain.com" />
</intent-filter>
```

**Klaviyo Universal Tracking Links** (e.g., `https://trk.yourdomain.com/u/abc123`)

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

**Testing deep links:**

```bash
# Custom URL scheme
adb shell am start -W -a android.intent.action.VIEW -d "myapp://product/123" com.your.package

# App link
adb shell am start -W -a android.intent.action.VIEW -d "https://yourdomain.com/product/123" com.your.package
```

For complete Android App Links setup including domain verification, see the [Android SDK Deep Linking Guide](https://github.com/klaviyo/klaviyo-android-sdk#deep-linking).

### Handling Tracking Links with go_router

Use go_router's `redirect` callback to pass URLs to Klaviyo for tracking:

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
    // Fire-and-forget — Klaviyo tracks the link in the background
    KlaviyoSDK().handleUniversalTrackingLink(state.uri.toString());
    return null;
  },
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await KlaviyoSDK().initialize(apiKey: 'YOUR_API_KEY');

  runApp(MaterialApp.router(routerConfig: router));
}
```

**How It Works**

1. **URL arrives** via go_router's routing system
2. **`redirect` callback fires** with the URL
3. **Call `handleUniversalTrackingLink()`** - validates and returns immediately
4. **Returns `true`** if it's a Klaviyo tracking link (format: `https://domain/u/...`), `false` otherwise
5. **Native SDK tracks** the click event in the background (fire-and-forget)
6. **Native SDK resolves** the link and your Flutter routing library handles the final destination

**Note**: `handleUniversalTrackingLink()` is synchronous - it validates the URL and returns a bool immediately, while the native tracking happens asynchronously in the background.

## Geofencing

The Klaviyo Flutter SDK supports geofencing for location-based event tracking. The full location module is **not included by default** — see [Enabling Geofencing](#enabling-geofencing) to opt in.

```dart
// Start monitoring geofences (requires location permissions)
await KlaviyoSDK().registerGeofencing();
```
```dart
// Stop monitoring all geofences
await KlaviyoSDK().unregisterGeofencing();
```

Without the full location module enabled, geofencing methods return error code `GEOFENCING_NOT_AVAILABLE` with instructions to enable it.

## Optional Module Configuration

### Enabling Geofencing

The SDK includes lightweight location interfaces by default but requires the full location module for geofencing to work.

**Android** — add to `android/gradle.properties`:

```properties
klaviyoIncludeLocation=true
```

This includes the full `location` module with Google Play Services and adds the following permissions to your merged manifest:
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.ACCESS_BACKGROUND_LOCATION`

**iOS** — add to `ios/Podfile` before `flutter_install_all_ios_pods`:

```ruby
ENV['KLAVIYO_INCLUDE_LOCATION'] = 'true'
```

This includes the `KlaviyoLocation` pod. You'll also need location permission descriptions in `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location for geofencing features.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location for geofence monitoring.</string>
```

### Disabling In-App Forms

In-app forms are **enabled by default**. To opt out (for a smaller SDK footprint):

**Android** — add to `android/gradle.properties`:

```properties
klaviyoIncludeForms=false
```

**iOS** — add to `ios/Podfile` before `flutter_install_all_ios_pods`:

```ruby
ENV['KLAVIYO_INCLUDE_FORMS'] = 'false'
```

Without the forms module, forms methods will log an error and no-op gracefully (error code: `FORMS_NOT_AVAILABLE`).

## Profile Reset (Logout)

```dart
// Reset profile when user logs out
await KlaviyoSDK().resetProfile();
```

## SDK Logging

SDK logging is enabled by default. To silence all Klaviyo SDK logging (native and Dart-side) at runtime:

```dart
await KlaviyoSDK().setLoggingEnabled(false); // silence all SDK logging
final enabled = await KlaviyoSDK().isLoggingEnabled(); // read current state
```

Both methods can be called before `initialize()` — useful for suppressing logs emitted during SDK startup. `isLoggingEnabled()` reports the native SDK's current logging state, and both methods throw a `KlaviyoException` if the native call fails.

Platform notes:

- **iOS**: The toggle does not affect `KlaviyoSwiftExtension` (used for rich push), which runs in a separate app-extension process.
- **Android**: The native SDK uses log levels rather than a boolean toggle. Disabling sets the level to `None`; re-enabling restores the level that was in effect before it was disabled (or the SDK default if it was never enabled at runtime). For finer-grained control of native log verbosity, use the [`com.klaviyo.core.log_level` manifest tag](#android).

To adjust the verbosity of the plugin's Dart-side logs (native logs are unaffected):

```dart
KlaviyoSDK().setLogLevel(KlaviyoLogLevel.debug);
```

While logging is disabled via `setLoggingEnabled(false)`, the level passed to `setLogLevel` is stored and takes effect once logging is re-enabled.

## API Reference

### KlaviyoSDK

The main SDK class. All methods are accessed via `KlaviyoSDK()`.

#### Initialization

| Method | Description |
|--------|-------------|
| `initialize({required String apiKey})` | Initialize the SDK |

#### Profile

| Method | Description |
|--------|-------------|
| `setProfile(KlaviyoProfile profile)` | Set a complete user profile |
| `setEmail(String email)` | Set user email |
| `setPhoneNumber(String phoneNumber)` | Set user phone number |
| `setExternalId(String externalId)` | Set external user ID |
| `getEmail()` | Get user email |
| `getPhoneNumber()` | Get user phone number |
| `getExternalId()` | Get external user ID |
| `setProfileProperties(Map<String, dynamic> properties)` | Set custom profile properties |
| `setProfileAttribute(String propertyKey, dynamic value)` | Set a single profile attribute |
| `resetProfile()` | Reset user profile (logout) |

#### Events

| Method | Description |
|--------|-------------|
| `createEvent(KlaviyoEvent event)` | Track a profile activity event |

#### Subscriptions

| Method | Description |
|--------|-------------|
| `createSubscription(KlaviyoSubscription subscription)` | Subscribe the current profile to a list and record its consent |

#### Push Notifications

| Method | Description |
|--------|-------------|
| `registerForPushNotifications()` | Register for push (iOS: APNs, Android: FCM) |
| `setPushToken(String token)` | Set push token manually |
| `getPushToken()` | Get current push token |
| `setBadgeCount(int count)` | Set badge count (iOS only) |

#### In-App Forms

| Method | Description |
|--------|-------------|
| `registerForInAppForms({InAppFormConfig? configuration})` | Register for in-app forms |
| `unregisterFromInAppForms()` | Unregister from in-app forms |

#### Geofencing

| Method | Description |
|--------|-------------|
| `registerGeofencing()` | Begin monitoring geofences |
| `unregisterGeofencing()` | Stop monitoring geofences |

#### Deep Linking

| Method | Description |
|--------|-------------|
| `handleUniversalTrackingLink(String url)` | Handle Klaviyo tracking links, returns `bool` |

#### Other

| Method | Description |
|--------|-------------|
| `setLoggingEnabled(bool enabled)` | Enable/disable SDK logging (native + Dart), callable before `initialize()`; does not affect iOS `KlaviyoSwiftExtension` — see [SDK Logging](#sdk-logging) |
| `isLoggingEnabled()` | Whether native SDK logging is enabled, returns `Future<bool>` |
| `setLogLevel(KlaviyoLogLevel logLevel)` | Set logging level (Flutter-side only) |
| `dispose()` | Clean up resources |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | Whether the SDK is initialized |
| `apiKey` | `String?` | Current API key |
| `onPushNotification` | `Stream<Map<String, dynamic>>` | Push notification events |
| `onFormLifecycleEvent` | `Stream<FormLifecycleEvent>` | Typed in-app form lifecycle events |
| `onPushAction` | `Stream<KlaviyoPushAction>` | Typed `open_url` / action-button push tap events |

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

#### KlaviyoSubscription

```dart
KlaviyoSubscription({
  required String listId,
  required KlaviyoSubscriptionChannels channels,
  String? customSource,
})

// Requests marketing consent on every identified channel
KlaviyoSubscription.allAvailableMarketing({
  required String listId,
  String? customSource,
})
```

#### KlaviyoSubscriptionChannels

```dart
KlaviyoSubscriptionChannels({
  Set<EmailConsent>? email,
  Set<MessagingConsent>? sms,
  Set<MessagingConsent>? whatsapp,
})
```

#### KlaviyoLocation

```dart
KlaviyoLocation({
  double? latitude,
  double? longitude,
  String? address1,
  String? address2,
  String? city,
  String? region,
  String? country,
  String? zip,
  String? timezone,
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

#### FormLifecycleEvent

Sealed class representing in-app form lifecycle events. Use Dart's pattern matching to handle each subtype exhaustively.

```dart
sealed class FormLifecycleEvent {
  final String formId;
  final String formName;
}

class FormShown extends FormLifecycleEvent { ... }
class FormDismissed extends FormLifecycleEvent { ... }
class FormCtaClicked extends FormLifecycleEvent {
  final String buttonLabel;
  final String deepLinkUrl;
}
```

### Enums

#### KlaviyoLogLevel

`none` | `error` | `warning` | `info` | `debug` | `verbose`

#### EventMetric

Predefined metrics:
- `EventMetric.openedApp`
- `EventMetric.viewedProduct`
- `EventMetric.addedToCart`
- `EventMetric.startedCheckout`

Custom metrics:
- `EventMetric.custom(String name)`

#### EmailConsent

`marketing` | `openTracking`

#### MessagingConsent

Applies to the SMS and WhatsApp channels.

`marketing` | `transactional`

### Extensions

#### KlaviyoNotificationMap (on `Map<String, dynamic>`)

| Property | Description |
|----------|-------------|
| `isKlaviyoNotification` | `bool` — whether the map is a Klaviyo push notification payload |

### Exceptions

All SDK exceptions extend `KlaviyoException`:

| Exception | Description |
|-----------|-------------|
| `KlaviyoNotInitializedException` | SDK used before `initialize()` |
| `KlaviyoInvalidApiKeyException` | Invalid API key provided |
| `KlaviyoNetworkException` | Network request failed (includes `statusCode`, `responseBody`) |
| `KlaviyoProfileException` | Profile operation failed |
| `KlaviyoEventException` | Event tracking failed |
| `KlaviyoPushException` | Push notification operation failed |
| `KlaviyoFormException` | In-app forms operation failed |
| `KlaviyoConfigurationException` | Configuration error |
| `KlaviyoPermissionException` | Missing required permission |

## Troubleshooting

### Android

**Push opens not tracked** — Verify `Klaviyo.handlePush(intent)` is called in both `onCreate` and `onNewIntent`. Use `singleTop` or `singleTask` launch mode. See the [example MainActivity](example/android/app/src/main/kotlin/com/klaviyo/flutterexample/MainActivity.kt).

**Push notifications not displaying** — Check Firebase setup (`google-services.json`, plugin applied in `build.gradle`). On Android 13+, runtime notification permission is required. Test with Firebase Console first to rule out Klaviyo-specific issues.

**Push tokens not being set** — Ensure Firebase is initialized before calling `FirebaseMessaging.instance.getToken()`. Initialize the SDK before calling `setPushToken()`.

**Deep links not working** — Verify intent filters in `AndroidManifest.xml`. Test with `adb shell am start -W -a android.intent.action.VIEW -d "yourscheme://path" com.your.package`. For App Links, verify `assetlinks.json` is accessible.

**Build failures** — Ensure `minSdkVersion 23`+. Remove direct references to `com.klaviyo:klaviyo-android-sdk` from your gradle files (the plugin includes it automatically).

**Debug logging** — Add to `AndroidManifest.xml`:
```xml
<meta-data android:name="com.klaviyo.core.log_level" android:value="1" />
```
Logging can also be toggled off entirely at runtime with `setLoggingEnabled(false)` — see [SDK Logging](#sdk-logging).

### iOS

For iOS-specific troubleshooting, refer to the [iOS SDK documentation](https://github.com/klaviyo/klaviyo-swift-sdk#troubleshooting).

### Common Issues

**Events not in dashboard** — Wait 5-10 minutes for processing. Verify your API key and that a profile is set (email, phone, or external ID) before tracking events. Verify that your Klaviyo account is active.

**"Not initialized" errors** — Call `KlaviyoSDK().initialize()` in `main()` before `runApp()`, and ensure you `await` the call:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KlaviyoSDK().initialize(apiKey: 'YOUR_API_KEY');
  runApp(MyApp());
}
```

### Getting Help

- **Native SDK Docs:** [Android](https://github.com/klaviyo/klaviyo-android-sdk) | [iOS](https://github.com/klaviyo/klaviyo-swift-sdk)
- **Klaviyo Support:** [https://help.klaviyo.com/](https://help.klaviyo.com/)
- **Report Bugs:** [GitHub Issues](https://github.com/klaviyo/klaviyo-flutter-sdk/issues)

When reporting issues, include: SDK version, Flutter version, platform and OS version, steps to reproduce, relevant logs (with debug logging enabled), and code snippets.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
