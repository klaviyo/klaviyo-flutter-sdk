# Flutter 1.0 API freeze prep: chunk C device test

**Target:** Flutter SDK 0.6.0 (local merge of klaviyo-flutter-sdk#181, #183, #185, #197 onto `origin/rel/0.6.0`, branch `ecm/test/chunk-c`, local only)
**Source:** https://claude.ai/artifact/SMBD4aGYoARxwK6NhKfzo6 (TC-001..TC-018), klaviyo-flutter-sdk#197 (MAGE-1654, new cases TC-019..TC-023)
**Author:** Claude (drone, chunk C) 2026-11-07
**Linear:** MAGE-1644
**Linear Doc:** none

## Prerequisites

- [ ] Flutter example app built from the merged worktree, test key LuYLmF (Mobile Dev). Never TRJ3wp.
- [ ] iOS simulator first, then Android emulator. One device at a time.
- [ ] iOS pushes: `xcrun simctl push`. Android pushes: `fcm-push-cli` (existing config, token via env var, never logged).
- [ ] Server-side reads are impossible from here: anything that needs the Klaviyo profile is UNVERIFIED unless a native log proves it.
- [ ] No push token values in notes or saved logs.

## Scope notes

- klaviyo-react-native-sdk#478 (MAGE-1641): **N/A, out of scope (RN).** TC-017 and TC-018 are marked N/A for that reason.
- #197 cases need the example rebuilt with the forms module and/or location module removed. Those are the only local edits to the example's build config (iOS Podfile env, Android gradle.properties). Recorded in the report.

## Test Cases

### TC-001 — flutter analyze flags every API that 1.0 removes

- **Area:** Init
- **Priority:** P1
- **Platforms:** All
- **Automation:** shell (`flutter analyze`), no device

**Preconditions:**
- Merged worktree. A scratch Dart file in the example calls each old API once.

**Steps:**
1. Call `onFormEvent`, `setLogLevel`, `handlePushNotificationReceived`, `handlePushNotificationOpened`, `dispose()`, `KlaviyoNativeWrapper`, `KlaviyoLogLevel`, `isKlaviyoNotification` from a scratch file.
2. Run `flutter analyze` on it.
3. Read each deprecation message.

**Expected:**
- One `deprecated_member_use` hint per old API, each naming a replacement and ending `Will be removed in 1.0.`

*Result:* Pass
*Notes:* [Android/iOS n/a, analyzer is platform-independent; Flutter 3.41.2, not the 3.38.7 the guide suggests, hints still showed] 8 deprecated_member_use hints, one per old API. Messages name replacements. OBSERVATION: `dispose` message reads "No longer needed; will be removed in 1.0" and `KlaviyoNativeWrapper` reads "...This class becomes internal in 1.0", so neither ends with the exact "Will be removed in 1.0." wording. Cosmetic, not a failure of the behavior.

---

### TC-002 — Replacement APIs work and deprecated ones still run

- **Area:** Init
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp

**Preconditions:**
- Example app running, SDK initialized, logging on.

**Steps:**
1. Toggle logging via `setLoggingEnabled(true)` (example UI) and confirm SDK log lines.
2. Trigger a form and watch `onFormLifecycleEvent`.
3. Exercise a deprecated call path the UI reaches.

**Expected:**
- Replacements work. Deprecated calls do not crash.

*Result:* Pending
*Notes:* PARTIAL, left Pending. Observed working: `setLoggingEnabled` (SDK log lines appear on both platforms) and `onFormLifecycleEvent` (formShown/formDismissed events on iOS and Android). NOT driven: calling the deprecated `setLogLevel` / `handlePushNotificationReceived` at runtime (the example UI has no control for them), so "deprecated calls do not crash" is UNVERIFIED.

---

### TC-003 — Push streams are not deprecated by #181

- **Area:** Push
- **Priority:** P1
- **Platforms:** All
- **Automation:** shell (`flutter analyze`) + mobile-mcp

**Preconditions:**
- Merged worktree.

**Steps:**
1. Run `flutter analyze` on the example, which subscribes to `onPushNotification` and `onPushAction`.
2. Open a push and confirm events still arrive.

**Expected:**
- No deprecation hint on either stream. Events arrive. (Open question for the reviewer: the brief says these should be deprecated; #181 does not.)

*Result:* Pass
*Notes:* [analyzer] `onPushNotification` and `onPushAction` produced no deprecation hint in the same scratch file. Runtime event arrival checked in TC-012 etc. Reviewer open question (brief says they should be deprecated) still stands.

---

### TC-004 — dispose() no longer kills the event streams

- **Area:** Init
- **Priority:** P0
- **Platforms:** All
- **Automation:** mobile-mcp + a local-only Dart test hook in the example if the UI has no dispose control

**Preconditions:**
- Example app with push listener, form listener, auth token provider registered.

**Steps:**
1. Call `KlaviyoSDK().dispose()`.
2. Re-initialize and re-register listeners.
3. Trigger a push open event and a form lifecycle event.
4. Request an auth token from the native side.

**Expected:**
- Events still reach Dart. Token request reaches the provider. Before re-registering, the answer is `No auth token provider registered`.

*Result:* Pending
*Notes:* PARTIAL, left Pending because two of the four expected outcomes were not driven. [iOS] PARTIAL. Local-only harness button on the Push tab calls `KlaviyoSDK().dispose()`. After tapping it, a simctl push was delivered and opened: the Push tab status changed to `Push notification opened: Unknown` and the log shows `push_notification_opened`, so the push stream survived dispose (before #181 dispose closed the controllers). NOT driven: form lifecycle event after dispose, and the native auth-token request / `No auth token provider registered` text. Those parts are UNVERIFIED on iOS. [Android] PARTIAL. Same harness dispose button. After `dispose()` a Klaviyo push was delivered and displayed (`Order Update` with action buttons); tapping it produced Dart `push_notification_opened` and the Push tab status `Push notification opened: Order Update`, so the push stream survived dispose. `firebase_messaging` `onMessage` also still fired. NOT driven on either platform: form lifecycle after dispose, and the auth-token provider path (`No auth token provider registered`). Those are UNVERIFIED.

---

### TC-005 — Push token value is not in the logs

- **Area:** Push
- **Priority:** P0
- **Platforms:** All
- **Automation:** mobile-mcp + `simctl spawn log stream` / `adb logcat`

**Preconditions:**
- Logging enabled. Push permission granted.

**Steps:**
1. Capture native and Dart logs.
2. Cold start and register for push.
3. Search the capture for the token string (compare by hash, never print it).
4. Tap a push to open it.

**Expected:**
- `FCM token received` / `APNs token received` with no value. No `Setting push token:` or `Retrieved push token from SDK:`. Payload not printed on open.

*Result:* Pass
*Notes:* [iOS] iPhone 17 Pro sim, iOS 26.5, ad-hoc-signed build (a `flutter build --no-codesign` build has no aps-environment entitlement, registration fails with "no valid aps-environment"; used xcodebuild ad-hoc signing instead, no source change). Logging on. Native log has exactly one `APNs token received` (subsystem com.klaviyo.flutter) and a Dart `push_token_received` event. 0 lines of `Setting push token:` / `Retrieved push token from SDK:`. 0 runs of 64+ hex chars in the full capture, so the APNs token never appears. Opened a simctl push (marker string in payload): log shows `Push notification opened` and `push_notification_opened`, 0 occurrences of the payload marker. [Android] pending. | [Android] Fresh app data, init with LuYLmF, logcat cleared before. Capture of 4663 lines. Plugin/Dart tags (flutter, KlaviyoFlutter, CHUNKC): 0 lines contain the FCM token, and no `Setting push token:` / `Retrieved push token from SDK:` lines. CAVEAT, NOT a PR defect: the example sets `com.klaviyo.core.log_level=1` (verbose) in its manifest, so the NATIVE Klaviyo Android SDK itself logs the token (10 lines under tags `Klaviyo.SharedPreferencesDataStore` and `KlaviyoApiClient`: `push_token=<value>` and the queued push-token request). Those come from the native SDK, not from the plugin #181 edited. Anyone pasting a verbose Android log will still leak the token; worth a note for the 1.0 docs. Also no `FCM token received` plugin line appeared in this capture (the plugin's Android token-received log may not run on this path). Push-open payload on Android was not captured separately. [iOS] see above.

---

### TC-006 — Profile values are not in Dart logs

- **Area:** Profile
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp + log capture

**Preconditions:**
- Logging enabled.

**Steps:**
1. Call `setEmail`, `setPhoneNumber`, `setExternalId` with recognizable values.
2. Read the log.

**Expected:**
- No `Email set:`, `Phone number set:`, `External ID set:` lines and none of the values.

*Result:* Pass
*Notes:* [iOS] Set email, phone, external ID via the Profile tab (profile card showed all three). Full 53k-line capture: 0 occurrences of the three values, 0 `Email set:`/`Phone number set:`/`External ID set:` lines. [Android] pending. | [Android] Set email, phone, external ID (profile card showed all three). Plugin/Dart tags: 0 occurrences of the values and 0 `Email set:` / `Phone number set:` / `External ID set:` lines. CAVEAT, same as TC-005: with the example's verbose native log level the NATIVE Klaviyo SDK logs the email/phone/external-id values in its queued profile requests (tags `KlaviyoApiClient`, `Klaviyo.SharedPreferencesDataStore`). Not part of #181 but relevant to the "no values in logs" goal.

---

### TC-007 — iOS plugin logger is silent when logging is off

- **Area:** Init
- **Priority:** P2
- **Platforms:** iOS
- **Automation:** mobile-mcp + `simctl spawn log stream`

**Preconditions:**
- `setLoggingEnabled(false)`.

**Steps:**
1. Cold start and register for push.
2. Filter the unified log for the plugin subsystem.
3. Enable logging and repeat.

**Expected:**
- No plugin lines while disabled. Lines appear when enabled.

*Result:* Pass
*Notes:* [iOS] Logging OFF run: `--dart-define CHUNKC_LOG=false`, fresh install, unsigned (`--no-codesign`) build, tapped Enable Push and Allow. The registration attempt hits a failure path that the plugin logs when logging is on (verified in the earlier logging-on run of the same unsigned build: `Failed to register for remote notifications: no valid aps-environment`). With logging off: 0 lines in subsystem com.klaviyo.flutter over the whole run. Logging ON run (signed build): the same subsystem prints `APNs token received` and `Push notification opened`.

---

### TC-008 — iOS silent push reaches Dart through the AppDelegate forward

- **Area:** Push
- **Priority:** P1
- **Platforms:** iOS
- **Automation:** mobile-mcp + `xcrun simctl push`

**Preconditions:**
- Example AppDelegate forwards `didReceiveRemoteNotification:fetchCompletionHandler:` to `handleSilentPush` (check; if absent, record and do not edit PR code).

**Steps:**
1. Send a content-available push in foreground, then in background.
2. Watch `onPushNotification` for `silent_push_received`.

**Expected:**
- Event arrives in both states. Note: `simctl push` may not exercise the real APNs silent path; record as such.

*Result:* Pending
*Notes:* [iOS] UNVERIFIED (simulator limit). Example AppDelegate does forward pure silent pushes to `handleSilentPush` (checked in source). But a content-available-only `xcrun simctl push` (foreground and background) produced no `Silent push received` and no `silent_push_received` event. A control run in foreground with no dispose behaved the same, so the cause is the simulator path, not the PRs. Needs a real device with a real APNs silent push.

---

### TC-009 — iOS does not deliver silent push after swipe-away

- **Area:** Push
- **Priority:** P2
- **Platforms:** iOS
- **Automation:** mobile-mcp + `xcrun simctl push`

**Preconditions:**
- Same as TC-008.

**Steps:**
1. Swipe the app away.
2. Send a silent push.
3. Open the app and check for an event.

**Expected:**
- No event for the missed push. (Simulator behavior may differ from device; record.)

*Result:* Pending
*Notes:* [iOS] UNVERIFIED: depends on TC-008 delivering at all. The simulator never delivers silent pushes through `simctl push` here, so "not delivered after swipe-away" proves nothing.

---

### TC-010 — Android silent push is delivered in background, dropped when killed

- **Area:** Push
- **Priority:** P2
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- Android example with FCM set up.

**Steps:**
1. Send a data-only push with the app in the background.
2. Force stop the app, send another.

**Expected:**
- Background push arrives as `silent_push_received`. Push after force stop is not delivered.

*Result:* Pass
*Notes:* [Android] ProxyFriendly_36, API 36. Data-only FCM message (`_k` present, no title/body, marker value in a data key) via fcm-push-cli. BACKGROUND (app alive, on home screen): native `KlaviyoFlutterPushService: Silent push received: forwarding to Flutter event stream` then Dart `Silent push received: {_k: ..., chunkc_silent: <marker>}`, so it arrives as `silent_push_received`. FORCE-STOPPED (`am force-stop`, pidof empty): push accepted by FCM, process never started (pid still empty 8 s later), 0 marker or silent lines; opening the app afterwards also showed no delayed delivery (nothing queued). Matches the README limit. A first attempt was invalid (my script ran from the wrong directory and sent nothing); redone. NOT tested: swiped-away (not force-stopped) app, which the README says Android may also drop.

---

### TC-011 — README limits match what was observed

- **Area:** Push
- **Priority:** P2
- **Platforms:** All
- **Automation:** none (read and compare)

**Preconditions:**
- TC-008 to TC-010 done.

**Steps:**
1. Read the silent push section of the merged README.
2. Compare each limit with the results.

**Expected:**
- Every stated limit matches.

*Result:* Pending
*Notes:* PARTIAL, left Pending. README limit "Android does not deliver while the app is killed": matches TC-010 (force-stop, nothing queued). "iOS needs AppDelegate forwarding": the example AppDelegate does forward pure silent pushes. "iOS does not deliver after swipe-away": UNVERIFIED (simulator never delivered silent pushes, see TC-008/009). Android swiped-away (not force-stopped) was not tested either.

---

### TC-012 — Android with firebase_messaging: Klaviyo push is displayed (MOST IMPORTANT)

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + `./gradlew :app:processDebugMainManifest` + fcm-push-cli

**Preconditions:**
- Example has `firebase_messaging` installed. Klaviyo service declared in the example's own manifest, no `android:priority`, no `tools:node="remove"` on Firebase's service (this is what #185 ships; do not add chunk D's harness edit).
- Device registered.

**Steps:**
1. Run `./gradlew :app:processDebugMainManifest` and quote the `MESSAGING_EVENT` service order in the merged manifest.
2. `adb shell cmd package resolve-service` for the `MESSAGING_EVENT` intent and note which service resolves first.
3. Kill the app (`am kill` with the app backgrounded; force-stop blocks FCM).
4. Send a Klaviyo push (`_k` key) with `fcm-push-cli`.
5. Check the notification shade and logcat.
6. Repeat with the app in the foreground.

**Expected:**
- Klaviyo's service is first in the merged manifest and resolves first. A Klaviyo notification is displayed with the app killed.

*Result:* Pass
*Notes:* [Android] ProxyFriendly_36 emulator, Android 16 (API 36), arm64. Example as merged: `firebase_messaging` 16.7.1 installed, `KlaviyoFlutterPushService` declared in the example manifest with NO priority, NO `tools:node="remove"` on Firebase's service (no chunk D harness edit). MERGED MANIFEST (`./gradlew :app:processDebugMainManifest`, MESSAGING_EVENT services in file order): 1 `com.klaviyo.klaviyo_flutter_sdk.KlaviyoFlutterPushService` (exported=false, no priority), 2 `io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService` (no priority), 3 `com.google.firebase.messaging.FirebaseMessagingService` (priority -500). ON DEVICE (`adb shell cmd package query-services -a com.google.firebase.MESSAGING_EVENT`): Service #0 KlaviyoFlutterPushService, #1 FlutterFirebaseMessagingService, #2 FirebaseMessagingService (priority -500); Klaviyo resolves first. PUSH: app killed (`am kill`, pidof empty), data push with `_k` sent via fcm-push-cli (`fcm push successfully send`); process 5407 was started by FlutterFirebaseMessagingReceiver (the broadcast receiver, expected), logcat shows `KlaviyoNotification` building the notification (action-button deep-link messages), and dumpsys shows the app posted a notification titled `Order Update` with 3 actions. PASS for the background/killed path. Foreground path and the `firebase_messaging` callback for non-Klaviyo messages were not driven in this run. NOTE: first two sends returned FCM `NotRegistered` because the emulator's FCM token was stale; fixed by deleting and re-fetching the token via a local harness hook, not a PR issue.

---

### TC-013 — Baseline: no declaration in the app manifest

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- Same as TC-012 with the Klaviyo service declaration temporarily removed (local only).

**Steps:**
1. Capture merged-manifest order and `resolve-service` output.
2. Send a Klaviyo push in the background.

**Expected:**
- Control run: record what happens. Not a bug report.

*Result:* Pass
*Notes:* [Android] Control run, declaration temporarily removed from the example manifest (local only, restored after). Merged manifest MESSAGING_EVENT order: 1 FlutterFirebaseMessagingService, 2 KlaviyoFlutterPushService, 3 FirebaseMessagingService(-500). Device `query-services` order matches: Firebase first. App killed (pidof empty), push sent OK; process started by FlutterFirebaseMessagingReceiver; app posted 0 notifications and logcat has 0 `KlaviyoNotification` lines. So without the declaration Klaviyo push is NOT displayed. This is the bug #185 documents, reproduced. Control only, not a defect.

---

### TC-014 — Android subclass of KlaviyoFlutterPushService

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- Local-only subclass in the example overriding `onMessageReceived`, calling `super` first, logging one line. Declared in the app manifest. Per the merged README, the base service is removed with `tools:node="remove"` or equivalent as documented.

**Steps:**
1. Send a Klaviyo push in background.
2. Send a non-Klaviyo FCM message.
3. Check logcat and `resolve-service`.

**Expected:**
- Subclass runs for both. Klaviyo push displayed.

*Result:* Pass
*Notes:* [Android] Local-only `ChunkCPushService : KlaviyoFlutterPushService` overriding `onMessageReceived`, calling `super` first, logging one line; declared in the example manifest in place of the plugin class. Device `query-services` order: ChunkCPushService, FlutterFirebaseMessagingService, KlaviyoFlutterPushService (base, still merged from the library manifest, third), FirebaseMessagingService(-500). Killed-app Klaviyo push: subclass log line fired (keys `_k, action_buttons, body, orderId, title`), `KlaviyoNotification` lines present, `Order Update` displayed. Non-Klaviyo data-only message in background: subclass ran (keys=[chunkc_other]), 0 `KlaviyoNotification` lines, nothing displayed. Non-Klaviyo `notification` message in background: displayed by the system as `Other app push`, matching the README. NOT exercised: the review concern about an app id that sorts after `com.klaviyo.*` (this example id, com.klaviyo.flutterexample, sorts before the library class package). DOC GAP FOUND: the example app cannot compile a subclass (`Cannot access FirebaseMessagingService`, `Unresolved reference RemoteMessage`) because the plugin declares `firebase-messaging` as `implementation`. An app must add `com.google.firebase:firebase-messaging` to its own dependencies. The README subclass section does not say so (local harness added the dependency to example/android/app/build.gradle; reverted).

---

### TC-015 — Android priority safeguard changes nothing for the good path

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- Same as TC-012 plus `android:priority="1"`.

**Steps:**
1. Send a Klaviyo push in the background with the app killed.

**Expected:**
- Displayed. Same as TC-012.

*Result:* Pass
*Notes:* [Android] Same app as TC-012 plus `android:priority="1"` on the intent-filter (local edit, restored after). Device `query-services`: Klaviyo priority=1 first, Firebase service priority=0, FirebaseMessagingService -500. App killed, push sent, `KlaviyoNotification` log lines present, app posted `Order Update`. Same outcome as TC-012, so the safeguard is harmless on the good path.

---

### TC-016 — Android token rotation reaches Klaviyo

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + logcat

**Preconditions:**
- Same as TC-012.

**Steps:**
1. Rotate the token (`deleteToken()` then `getToken()`, or `adb shell pm clear` equivalent that keeps the install).
2. Watch logs for the rotation being handled natively. Server-side profile check is not possible.
3. Check whether `onTokenRefresh` fires in Dart.

**Expected:**
- Native `onNewToken` handled by Klaviyo; `onTokenRefresh` does not fire. Profile update UNVERIFIED (server side).

*Result:* Pass
*Notes:* [Android] Declaration as in TC-012. Local harness button on the Push tab calls `FirebaseMessaging.instance.deleteToken()` then `getToken()` with the app running. The token changed. Native log right after: `Klaviyo.SharedPreferencesDataStore: push_token=<TOK>` then `Enqueuing Push Token request` and a `PushTokenApiRequest` persisted, so Klaviyo stored and queued the new token. The log has no explicit `onNewToken` line, so the trigger is INFERRED (the Dart `onTokenRefresh` handler, the only other path that calls setPushToken, did not run), not directly observed. `FirebaseMessaging.onTokenRefresh` did not fire (0 `FCM Token refreshed` lines, the example logs one on every refresh), matching the #185 README. UNVERIFIED: that the new token reached the Klaviyo profile server side (server reads are not possible from here). Caveat: `deleteToken()` is a client-triggered rotation; whether FCM calls `onNewToken` on the Klaviyo service for server-side rotations was not exercised.

---

### TC-017 — Android with React Native Firebase: Klaviyo push is displayed

- **Area:** Push
- **Priority:** P0
- **Platforms:** React Native
- **Automation:** none

**Preconditions:**
- klaviyo-react-native-sdk#478.

**Steps:**
1. Out of scope for this drone.

**Expected:**
- N/A (RN).

*Result:* Skip
*Notes:* N/A: klaviyo-react-native-sdk#478 is out of scope for this run (RN repo, per dispatch).

---

### TC-018 — RN token rotation matches Flutter

- **Area:** Push
- **Priority:** P1
- **Platforms:** React Native
- **Automation:** none

**Preconditions:**
- klaviyo-react-native-sdk#478.

**Steps:**
1. Out of scope for this drone.

**Expected:**
- N/A (RN).

*Result:* Skip
*Notes:* N/A: klaviyo-react-native-sdk#478 is out of scope for this run (RN repo, per dispatch).

---

### TC-019 — registerForInAppForms throws KlaviyoException with the native code when the forms module is missing

- **Area:** Forms
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp. Build with forms removed (iOS `KLAVIYO_INCLUDE_FORMS=false`, Android `klaviyoIncludeForms=false`).

**Preconditions:**
- Example built without the forms module. SDK initialized with LuYLmF.

**Steps:**
1. Open the Forms tab and tap Register.
2. Read the status text and the log.

**Expected:**
- The call throws `KlaviyoException`. The message shows `(Code: FORMS_NOT_AVAILABLE)`. Not swallowed as a warning.

*Result:* Pass
*Notes:* [iOS] Build with Podfile `KLAVIYO_INCLUDE_FORMS=false` and `KLAVIYO_INCLUDE_LOCATION=false` (no KlaviyoForms/KlaviyoLocation frameworks in the .app), SDK initialized with LuYLmF, location-always granted. Forms tab Register -> status shows `KlaviyoException: Failed to register for in-app forms: In-App Forms requires the forms module... (Code: FORMS_NOT_AVAILABLE)`. Thrown, not swallowed. | [Android] ProxyFriendly_36 API 36. Build with `klaviyoIncludeForms=false` and `klaviyoIncludeLocation=false` in example/android/gradle.properties (local edit, restored after), SDK initialized with LuYLmF. Forms tab Register -> `Failed to register for forms: KlaviyoException: Failed to register for in-app forms: forms module not installed. Add 'com.klaviyo:forms' dependency... (Code: FORMS_NOT_AVAILABLE)`.

---

### TC-020 — unregisterFromInAppForms throws KlaviyoException with the native code when the forms module is missing

- **Area:** Forms
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp

**Preconditions:**
- Same build as TC-019.

**Steps:**
1. On the Forms tab tap Unregister.
2. Read the status text.

**Expected:**
- `KlaviyoException` with `(Code: FORMS_NOT_AVAILABLE)`.

*Result:* Pass
*Notes:* [iOS] Build with Podfile `KLAVIYO_INCLUDE_FORMS=false` and `KLAVIYO_INCLUDE_LOCATION=false` (no KlaviyoForms/KlaviyoLocation frameworks in the .app), SDK initialized with LuYLmF, location-always granted. Unregister (local harness button, because the example only shows Unregister after a successful register) -> `KlaviyoException: Failed to unregister from in-app forms ... (Code: FORMS_NOT_AVAILABLE)`. | [Android] ProxyFriendly_36 API 36. Build with `klaviyoIncludeForms=false` and `klaviyoIncludeLocation=false` in example/android/gradle.properties (local edit, restored after), SDK initialized with LuYLmF. Unregister (harness button) -> `Failed to unregister from forms: KlaviyoException: ... forms module not installed ... (Code: FORMS_NOT_AVAILABLE)`. First tap landed before the status text grew and was a no-op; retried.

---

### TC-021 — registerGeofencing throws KlaviyoException with the native code when location is not set up

- **Area:** Geofencing
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp. Build with location removed (iOS `KLAVIYO_INCLUDE_LOCATION` unset, Android `klaviyoIncludeLocation=false`).

**Preconditions:**
- Example built without the location module. Location permission state recorded.

**Steps:**
1. Open the Geofencing tab and tap Register.
2. Read the status text.
3. Tap Unregister and read the status text.

**Expected:**
- Both throw `KlaviyoException` with `(Code: GEOFENCING_NOT_AVAILABLE)`.

*Result:* Pass
*Notes:* [iOS] Build with Podfile `KLAVIYO_INCLUDE_FORMS=false` and `KLAVIYO_INCLUDE_LOCATION=false` (no KlaviyoForms/KlaviyoLocation frameworks in the .app), SDK initialized with LuYLmF, location-always granted. Register -> `KlaviyoException: Failed to register for geofencing: Geofencing requires the location module... (Code: GEOFENCING_NOT_AVAILABLE)`. Unregister (harness button) -> `... Failed to unregister from geofencing ... (Code: GEOFENCING_NOT_AVAILABLE)`. | [Android] ProxyFriendly_36 API 36. Build with `klaviyoIncludeForms=false` and `klaviyoIncludeLocation=false` in example/android/gradle.properties (local edit, restored after), SDK initialized with LuYLmF. The example gates its own Register button on the Android "Always" permission, so a harness button without that gate was used to reach the plugin. Register -> `KlaviyoException: Failed to register for geofencing: Geofencing requires the full location module. Add 'klaviyoIncludeLocation=true' to gradle.properties (Code: GEOFENCING_NOT_AVAILABLE)`. Unregister -> same message with `Failed to unregister from geofencing`, same code.

---

### TC-022 — getCurrentGeofences throws KlaviyoException with the native code when location is not set up

- **Area:** Geofencing
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp

**Preconditions:**
- Same build as TC-021.

**Steps:**
1. On the Geofencing tab tap the control that lists current geofences.
2. Read the status text.

**Expected:**
- `KlaviyoException` with `(Code: GEOFENCING_NOT_AVAILABLE)`, not an empty list.

*Result:* Pass
*Notes:* [iOS] Build with Podfile `KLAVIYO_INCLUDE_FORMS=false` and `KLAVIYO_INCLUDE_LOCATION=false` (no KlaviyoForms/KlaviyoLocation frameworks in the .app), SDK initialized with LuYLmF, location-always granted. List geofences (harness button) -> `KlaviyoException: Failed to get current geofences: Geofencing requires the location module... (Code: GEOFENCING_NOT_AVAILABLE)`, not an empty list. | [Android] ProxyFriendly_36 API 36. Build with `klaviyoIncludeForms=false` and `klaviyoIncludeLocation=false` in example/android/gradle.properties (local edit, restored after), SDK initialized with LuYLmF. List geofences (harness button) -> `KlaviyoException: Failed to get current geofences: Geofencing requires the full location module ... (Code: GEOFENCING_NOT_AVAILABLE)`, not an empty list.

---

### TC-023 — Forms and geofencing success path is unchanged

- **Area:** Forms
- **Priority:** P1
- **Platforms:** All
- **Automation:** mobile-mcp (+ `simctl location` / `adb emu geo` for location)

**Preconditions:**
- Default example build (forms and location modules present). SDK initialized.

**Steps:**
1. Register for in-app forms, then unregister.
2. Grant location permission, register geofencing, list current geofences, unregister.

**Expected:**
- No exception. Status shows success. `getCurrentGeofences` returns a list (possibly empty).

*Result:* Pass
*Notes:* [iOS] Default build (forms + location). Forms: Register -> status `Registered for in-app forms`, a real form rendered (`formShown`), dismissed (`formDismissed`), Unregister -> `Unregistered from in-app forms`. Geofencing: location-always granted via `simctl privacy`, location set via `simctl location`; Register -> `Loaded 0 geofence(s)` (getCurrentGeofences returned an empty list, no exception), Refresh OK, Unregister -> `Geofencing unregistered`. No exception anywhere. | [Android] ProxyFriendly_36 API 36, default build (forms + location modules), LuYLmF. Forms: Register -> real forms rendered (`formShown`/`formDismissed` lifecycle events listed, several forms shown in sequence), Unregister -> `Unregistered from in-app forms`, no exception. Geofencing: ACCESS_FINE/COARSE_LOCATION granted via `adb pm grant` (the example's own Register button also requires Always, which was not granted, so the harness no-gate button was used to reach the plugin): register -> no error, list -> `Loaded 0 geofence(s)`, unregister -> `Geofencing unregistered`. No exception. NOTE: mid-run the emulator hung (adb unresponsive after a form opened a Chrome link) and was cold-restarted; app data survived.

---
