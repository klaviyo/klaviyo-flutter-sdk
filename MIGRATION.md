# Migrating from `klaviyo_flutter` to `klaviyo_flutter_sdk`

This guide covers migrating from the community
[`klaviyo_flutter`](https://pub.dev/packages/klaviyo_flutter) package to the
official [`klaviyo_flutter_sdk`](https://pub.dev/packages/klaviyo_flutter_sdk)
published by Klaviyo.

The official SDK includes a backwards-compatibility layer that lets you migrate
incrementally. You can start with a **minimal migration** (swap the dependency,
change one import, get running) and then work through deprecation warnings at
your own pace — or you can do a **full migration** in one pass.

> **Compatibility note:** All deprecated bridge APIs will be removed in version
> 2.0 of `klaviyo_flutter_sdk`. We recommend completing the full migration
> before upgrading to 2.0.

---

## Minimal Migration

The goal here is to get your app compiling against the official SDK with the
fewest possible code changes. You will see deprecation warnings — that's
expected and intentional. They serve as a guided checklist you can work through
later.

### Step 1: Swap the dependency

```yaml
# pubspec.yaml

# Remove:
dependencies:
  klaviyo_flutter: ^0.2.0

# Add:
dependencies:
  klaviyo_flutter_sdk: ^0.1.0
```

Then run `flutter pub get`.

### Step 2: Update your import

Find and replace across your project:

```dart
// Before
import 'package:klaviyo_flutter/klaviyo_flutter.dart';

// After
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
```

### That's it

Your existing Dart code — `Klaviyo.instance.initialize(...)`,
`Klaviyo.instance.logEvent(...)`, `Klaviyo.instance.setEmail(...)`,
`KlaviyoProfile(id: '...', address1: '...')`, and so on — will compile and work
as before. Every call will produce a deprecation warning pointing you to the
official API equivalent.

### Push notifications (additional setup if applicable)

If you were using push notifications with the community SDK, be aware that the
official SDK handles push processing natively rather than through Dart-level
`handlePush()` calls. Your existing `handlePush()` calls will still compile
(they become no-ops via the bridge), but to get push tracking working with the
official SDK you will need to update your native setup:

- **iOS:** Update `AppDelegate.swift` — see the
  [README](https://pub.dev/packages/klaviyo_flutter_sdk) for details.
- **Android:** Update `MainActivity.kt` and declare `KlaviyoPushService` in
  `AndroidManifest.xml` — see the
  [README](https://pub.dev/packages/klaviyo_flutter_sdk) for details.

If you aren't using push notifications, no native changes are needed.

### What about `handlePush`?

If you were calling `Klaviyo.instance.handlePush(message.data)` from a
`FirebaseMessaging.onBackgroundMessage` handler, this call is now a no-op. The
official SDK handles push processing automatically in the native layer. The
bridge method still exists so your code compiles, but you can safely remove it.

---

## Full Migration

This section walks through every API change from the community SDK to the
official SDK. After completing these steps, your code will have zero deprecation
warnings and be fully ready for version 2.0.

### Entry point

The community SDK uses a static singleton accessor. The official SDK uses a
factory constructor that returns the same singleton internally.

```dart
// Before
Klaviyo.instance.setEmail('user@example.com');

// After
KlaviyoSDK().setEmail('user@example.com');
```

### Initialization

The API key parameter changes from positional to named.

```dart
// Before
await Klaviyo.instance.initialize('YOUR_API_KEY');

// After
await KlaviyoSDK().initialize(apiKey: 'YOUR_API_KEY');
```

### Event tracking

The community SDK uses a flat `logEvent(name, metadata)` call. The official SDK
uses a typed `KlaviyoEvent` model with predefined and custom metrics.

```dart
// Before
await Klaviyo.instance.logEvent(
  '\$successful_payment',
  {'\$value': 'paymentValue'},
);

// After — custom event
await KlaviyoSDK().createEvent(
  KlaviyoEvent.custom(
    metric: '\$successful_payment',
    properties: {'\$value': 'paymentValue'},
  ),
);

// After — predefined event
await KlaviyoSDK().createEvent(
  KlaviyoEvent(
    name: EventMetric.viewedProduct,
    properties: {'product_id': 'abc123'},
  ),
);
```

> **Return type change:** `logEvent` returned `Future<String>`.
> `createEvent` returns `Future<void>`. If you were using the return value,
> remove that dependency — the string was a platform-specific artifact with no
> guaranteed content.

### Push token registration

```dart
// Before
Klaviyo.instance.sendTokenToKlaviyo(token);

// After
KlaviyoSDK().setPushToken(token);
```

The official SDK also provides an automatic approach that doesn't require
`firebase_messaging` as a dependency:

```dart
// New: automatic token registration
await KlaviyoSDK().registerForPushNotifications();

// Listen for token events
KlaviyoSDK().onPushNotification.listen((event) {
  if (event['type'] == 'push_token_received') {
    print('Token: ${event['data']['token']}');
  }
});
```

### Push notification handling

```dart
// Before
FirebaseMessaging.onBackgroundMessage(_handler);

Future<void> _handler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await Klaviyo.instance.handlePush(message.data);
}

// After — remove entirely
// The official SDK handles push processing automatically in the native layer.
// No Dart-level background handler is needed for Klaviyo pushes.
```

### Checking if a push is from Klaviyo

```dart
// Before
if (Klaviyo.instance.isKlaviyoPush(message.data)) { ... }

// After — inline the check
if (message.data.containsKey('_k')) { ... }
```

### Profile management — `updateProfile`

```dart
// Before
await Klaviyo.instance.updateProfile(profile);

// After
await KlaviyoSDK().setProfile(profile);
```

> **Return type change:** `updateProfile` returned `Future<String>`.
> `setProfile` returns `Future<void>`. As with `logEvent`, the return value
> was not meaningful.

### Profile management — individual setters

Methods with identical signatures that only change the entry point:

```dart
// Before                                    // After
Klaviyo.instance.setEmail(email)             KlaviyoSDK().setEmail(email)
Klaviyo.instance.getEmail()                  KlaviyoSDK().getEmail()
Klaviyo.instance.setPhoneNumber(phone)       KlaviyoSDK().setPhoneNumber(phone)
Klaviyo.instance.getPhoneNumber()            KlaviyoSDK().getPhoneNumber()
Klaviyo.instance.setExternalId(id)           KlaviyoSDK().setExternalId(id)
Klaviyo.instance.getExternalId()             KlaviyoSDK().getExternalId()
Klaviyo.instance.resetProfile()              KlaviyoSDK().resetProfile()
```

### Profile management — attribute setters

The community SDK had dedicated methods for individual profile attributes. The
official SDK uses `setProfileAttribute()` for individual fields,
`setProfileProperties()` for batching multiple fields, or `setProfile()` with a
full `KlaviyoProfile` object.

```dart
// Before
await Klaviyo.instance.setFirstName('Jane');
await Klaviyo.instance.setLastName('Doe');
await Klaviyo.instance.setTitle('Engineer');
await Klaviyo.instance.setOrganization('Acme');
await Klaviyo.instance.setImage('https://example.com/photo.jpg');

// After — option A: individual calls via setProfileAttribute
await KlaviyoSDK().setProfileAttribute('first_name', 'Jane');
await KlaviyoSDK().setProfileAttribute('last_name', 'Doe');
await KlaviyoSDK().setProfileAttribute('title', 'Engineer');
await KlaviyoSDK().setProfileAttribute('organization', 'Acme');
await KlaviyoSDK().setProfileAttribute('image', 'https://example.com/photo.jpg');

// After — option B: batch them in one call via setProfileProperties
await KlaviyoSDK().setProfileProperties({
  'first_name': 'Jane',
  'last_name': 'Doe',
  'title': 'Engineer',
  'organization': 'Acme',
  'image': 'https://example.com/photo.jpg',
});

// After — option C: use a full profile object
await KlaviyoSDK().setProfile(KlaviyoProfile(
  firstName: 'Jane',
  lastName: 'Doe',
  title: 'Engineer',
  organization: 'Acme',
  image: 'https://example.com/photo.jpg',
));
```

### Profile management — location setters

The community SDK had flat setters for individual location fields. The official
SDK uses `setProfileAttribute()` for individual fields, or
`setProfileProperties()` for batching multiple fields.

```dart
// Before
await Klaviyo.instance.setAddress1('123 Main St');
await Klaviyo.instance.setCity('Boston');
await Klaviyo.instance.setRegion('MA');
await Klaviyo.instance.setCountry('US');
await Klaviyo.instance.setZip('02101');
await Klaviyo.instance.setLatitude(42.3601);
await Klaviyo.instance.setLongitude(-71.0589);
await Klaviyo.instance.setTimezone('America/New_York');

// After — option A: individual calls via setProfileAttribute
await KlaviyoSDK().setProfileAttribute('address1', '123 Main St');
await KlaviyoSDK().setProfileAttribute('city', 'Boston');
await KlaviyoSDK().setProfileAttribute('region', 'MA');
await KlaviyoSDK().setProfileAttribute('country', 'US');
await KlaviyoSDK().setProfileAttribute('zip', '02101');
await KlaviyoSDK().setProfileAttribute('latitude', 42.3601);
await KlaviyoSDK().setProfileAttribute('longitude', -71.0589);
await KlaviyoSDK().setProfileAttribute('timezone', 'America/New_York');

// After — option B: batch them in one call via setProfileProperties
await KlaviyoSDK().setProfileProperties({
  'address1': '123 Main St',
  'city': 'Boston',
  'region': 'MA',
  'country': 'US',
  'zip': '02101',
  'latitude': 42.3601,
  'longitude': -71.0589,
  'timezone': 'America/New_York',
});
```

### Profile management — custom attributes

```dart
// Before
await Klaviyo.instance.setCustomAttribute('plan', 'premium');

// After
await KlaviyoSDK().setProfileAttribute('plan', 'premium');
```

> **Type change:** The community SDK's `setCustomAttribute` accepted
> `(String key, String value)`. The official SDK's `setProfileAttribute`
> accepts `(String key, dynamic value)`, so you can now pass non-string values
> directly.

### `KlaviyoProfile` model

The community SDK's `KlaviyoProfile` class differs from the official SDK in two
ways. Both are handled by deprecated compatibility parameters, but here's how
to do a clean migration:

**`id` → `externalId`:**

```dart
// Before
final profile = KlaviyoProfile(id: 'user_123', email: 'user@example.com');

// After
final profile = KlaviyoProfile(externalId: 'user_123', email: 'user@example.com');
```

**Flat location fields → nested `KlaviyoLocation`:**

```dart
// Before
final profile = KlaviyoProfile(
  email: 'user@example.com',
  address1: '123 Main St',
  region: 'MA',
  latitude: '42.3601',
  longitude: '-71.0589',
);

// After
final profile = KlaviyoProfile(
  email: 'user@example.com',
  location: KlaviyoLocation(
    address1: '123 Main St',
    region: 'MA',
    latitude: 42.3601,
    longitude: -71.0589,
  ),
);
```

> **Type change:** The community SDK stored `latitude` and `longitude` as
> `String?` on `KlaviyoProfile`. The official SDK's `KlaviyoLocation` uses
> `double?`. The deprecated compatibility parameters accept strings and parse
> them internally, but the clean migration should use doubles directly.

### Badge count

```dart
// Before
await Klaviyo.instance.setBadgeCount(5);

// After
KlaviyoSDK().setBadgeCount(5);
```

> **Return type change:** The community SDK returned `Future<void>`. The
> official SDK's `setBadgeCount` is a synchronous `void` method (fire-and-forget
> on iOS, no-op on Android). Remove any `await` on this call.

---

## New features in the official SDK

After migrating, you gain access to features that were not available in the
community SDK:

- **In-App Forms:** `registerForInAppForms()`, `unregisterFromInAppForms()`,
  and the `onFormEvent` stream.
- **Geofencing:** `registerGeofencing()`, `unregisterGeofencing()` (opt-in via
  build configuration).
- **Deep Linking:** `handleUniversalTrackingLink()` with `go_router`
  integration support.
- **Automatic push token registration:** `registerForPushNotifications()`
  without needing `firebase_messaging` as a dependency.
- **Push event stream:** `onPushNotification` for token events, open events,
  and errors.
- **Log level control:** `setLogLevel()` with granular levels.

See the [README](https://pub.dev/packages/klaviyo_flutter_sdk) for full
documentation on these features.

---

## Quick reference

| Community SDK (`klaviyo_flutter`) | Official SDK (`klaviyo_flutter_sdk`) |
|---|---|
| `Klaviyo.instance` | `KlaviyoSDK()` |
| `.initialize('key')` | `.initialize(apiKey: 'key')` |
| `.logEvent(name, meta)` | `.createEvent(KlaviyoEvent.custom(metric: name, properties: meta))` |
| `.sendTokenToKlaviyo(token)` | `.setPushToken(token)` |
| `.handlePush(data)` | Remove — handled automatically by native layer |
| `.isKlaviyoPush(data)` | `data.containsKey('_k')` |
| `.updateProfile(profile)` | `.setProfile(profile)` |
| `.setFirstName(name)` | `.setProfileAttribute('first_name', name)` |
| `.setLastName(name)` | `.setProfileAttribute('last_name', name)` |
| `.setOrganization(org)` | `.setProfileAttribute('organization', org)` |
| `.setTitle(title)` | `.setProfileAttribute('title', title)` |
| `.setImage(url)` | `.setProfileAttribute('image', url)` |
| `.setAddress1(addr)` | `.setProfileAttribute('address1', addr)` |
| `.setAddress2(addr)` | `.setProfileAttribute('address2', addr)` |
| `.setCity(city)` | `.setProfileAttribute('city', city)` |
| `.setCountry(country)` | `.setProfileAttribute('country', country)` |
| `.setRegion(region)` | `.setProfileAttribute('region', region)` |
| `.setZip(zip)` | `.setProfileAttribute('zip', zip)` |
| `.setLatitude(lat)` | `.setProfileAttribute('latitude', lat)` |
| `.setLongitude(lng)` | `.setProfileAttribute('longitude', lng)` |
| `.setTimezone(tz)` | `.setProfileAttribute('timezone', tz)` |
| `.setCustomAttribute(k, v)` | `.setProfileAttribute(k, v)` |
| `.setBadgeCount(n)` (async) | `.setBadgeCount(n)` (sync, no await) |
| `KlaviyoProfile(id: ...)` | `KlaviyoProfile(externalId: ...)` |
| `KlaviyoProfile(address1: ...)` | `KlaviyoProfile(location: KlaviyoLocation(address1: ...))` |
