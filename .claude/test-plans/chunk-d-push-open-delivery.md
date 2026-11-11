# Chunk D: push-open delivery (Flutter 1.0)

**Target:** Flutter SDK rel/0.6.0 + #187 + #184 + #189 (local merge `ecm/test/chunk-d`); Android SDK #615 linked locally (base rel/4.6.1)
**Source:** klaviyo-flutter-sdk#187, #184, #189; klaviyo-android-sdk#615 (MAGE-1034, MAGE-1577, MAGE-1574, MAGE-1481, MAGE-1582)
**Author:** Claude drone (test-plan design), 2026-11-07
**Linear:** unlinked
**Linear Doc:** none

## Prerequisites

- [ ] One device at a time. iOS simulator first (all iOS cases), shut down, then Android emulator.
- [ ] Example app built from worktree `klaviyo-flutter-sdk/.claude/worktrees/ecm-test-chunk-d` (branch `ecm/test/chunk-d`, never pushed).
- [ ] Android example uses the local android-sdk worktree for #615 (`configure-sdk.sh --android-local`).
- [ ] Test-profile Klaviyo public API key entered in the example's Profile tab. Test profile only, no campaigns.
- [ ] iOS pushes via `xcrun simctl push <udid> com.klaviyo.FlutterExample <payload.json>`. Payloads need the `_k` key to be treated as Klaviyo pushes.
- [ ] Android pushes via `fcm-push-cli` only if it works with its existing config and no login. Otherwise fall back to `adb shell am start` intents (documented as a deviation).
- [ ] Observation: Flutter `developer.log` (logger `KlaviyoExample`), native logs (`xcrun simctl spawn log stream` / `adb logcat`), Push tab status text.
- [ ] Known example-app limits: the Push tab subscribes to `onPushNotification` and `main.dart` subscribes to `onPushAction`; there is no second Dart subscriber and no iOS second engine. Android has a second engine only via `FirebaseMessaging.onBackgroundMessage`.

## Test Cases

### TC-001 — iOS cold-start push open reaches a late Dart subscriber

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS
- **Automation:** mobile-mcp + `xcrun simctl push`/`terminate`/`launch`

**Preconditions:**
- App installed, SDK initialized once with the test API key, push permission granted, then app terminated.

**Steps:**
1. Terminate the app.
2. Deliver a Klaviyo push with `xcrun simctl push`.
3. Tap the banner to cold-launch the app.
4. Without touching anything else, open the Push tab (the Dart listener subscribes late).

**Expected:**
- Push tab status shows `Push notification opened: <title>`.
- Native log shows the open was cached, then replayed.

*Result:* Pass
*Notes:* [iOS] iPhone 17 Pro sim, iOS 26.5. App terminated, `simctl push` (open.json), tapped banner, cold launch landed on Profile tab, then opened Push tab: status `Push notification opened: Unknown`. Native log `Flutter not ready. Caching notification open event.` ("Unknown" = example reads data['title'], iOS nests it under aps.alert; example limitation, not SDK.)

---

### TC-002 — iOS cold-start action-button tap reaches Dart

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS
- **Automation:** mobile-mcp + `xcrun simctl push` with a category that has action buttons

**Preconditions:**
- App installed, initialized, terminated. Payload carries action buttons registered by the SDK or the example's notification extension.

**Steps:**
1. Terminate the app.
2. Deliver a push with action buttons.
3. Long-press the banner and tap an action button.
4. Wait for the app to launch and initialize.

**Expected:**
- `onPushAction` logs `Push action button tapped — id: …, action: …`.
- Only one action event is delivered.

*Result:* Pass
*Notes:* [iOS] iPhone 17 Pro sim, iOS 26.5. DEVIATION: `simctl push` does not run the NSE, so no category was attached; I registered a local test category (`chunkd.actions`, customDismissAction, two actions) in the example's AppDelegate (local-only edit, uncommitted) and put `aps.category` in the payload. App terminated, long-look "Open App" tapped. Native log: `Flutter not ready. Caching notification open event.` + `Caching push action event.`. Dart (mirrored via debugPrint): `Native push action event: push_action_button_tapped` then example `Push action button tapped — id: com.klaviyo.chunkd.open_app, action: open_app`. One action event observed.

---

### TC-003 — Two Dart subscribers both get the held open event

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp

**Preconditions:**
- A cold-start open has been delivered and is held (as in TC-001 / TC-006).

**Steps:**
1. After the cold open, open the Push tab (subscriber A, sees the event).
2. Switch to another tab and back so the Push tab re-subscribes (subscriber B).

**Expected:**
- Each subscription receives the held open event (status shows the opened title again after re-subscribing).
- Gap: the example has no second concurrent subscriber on `onPushAction`; only the sequential-subscribe form of this case is covered.

*Result:* Pending
*Notes:* [iOS] After TC-001: Push tab (subscriber 1) showed the opened event; switched to Profile tab and back to Push: status still `Push notification opened: Unknown`. UNVERIFIED: I did not confirm the Push tab State is recreated on tab switch (ShellRoute may keep it alive), so this does not prove a second subscriber received the held event. Needs a log line on subscribe or a second concurrent subscriber to settle. [Android] Same gap: after the TC-006 cold tap, the Push tab subscribed late and showed the event once; I did not re-subscribe or add a second subscriber, so replay-to-every-subscriber is UNVERIFIED on Android too.

---

### TC-004 — iOS swipe-dismiss of a push with action buttons sends no open event

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS
- **Automation:** mobile-mcp (swipe) + `xcrun simctl push`

**Preconditions:**
- App initialized, category with `customDismissAction` (action buttons), app in background.

**Steps:**
1. Deliver the push.
2. Pull down the banner or notification, swipe it away (dismiss).
3. Bring the app to the foreground.
4. Check native log for `Push notification dismissed` and Dart log/Push tab status.

**Expected:**
- No `push_notification_opened` reaches Dart; Push tab status is unchanged.
- A pending cached open from earlier is cleared by the dismiss.

*Result:* Pass
*Notes:* [iOS] iPhone 17 Pro sim, iOS 26.5. Same local test category as TC-002 (customDismissAction). App alive in background, one push, cleared via Notification Center swipe-left > Clear. Live log stream: `Push notification dismissed` at 09:39:35, and nothing else (no `Push notification opened`, no Dart `push_notification_opened`/action lines). After foregrounding, Push tab status still `Push notification settings`. NOT verified: the second Expected bullet (a previously cached open being cleared by a dismiss); I did not stage that sequence. An earlier attempt at 09:37 and 09:38 produced no log because the dismiss fired but I read logs without the debug level; the stream run is the evidence.

---

### TC-005 — iOS secondary engine doesn't steal main-engine events

- **Area:** Push
- **Priority:** P1
- **Platforms:** iOS
- **Automation:** none available

**Preconditions:**
- A second Flutter engine on iOS.

**Steps:**
1. Check whether the example can start a second engine on iOS.

**Expected:**
- If it can, main engine still receives push/forms/JWT events. If not, record as a coverage gap.

*Result:* Pending
*Notes:* [iOS] BLOCKED (coverage gap, not run): the example app has no second Flutter engine on iOS (Firebase and `firebaseBackgroundHandler` are initialized only under `Platform.isAndroid` in main.dart; no workmanager / local-notifications plugin). #189's iOS per-engine stream handler is therefore untested on device; only the single-engine path ran (TC-001/002/004 all passed through the new EngineEventStream).

---

### TC-006 — Android cold-start push open reaches a late Dart subscriber

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- App installed, initialized with the test API key, FCM token registered, app force-stopped.

**Steps:**
1. Force-stop the app.
2. Send a Klaviyo data push (notification shown by the SDK).
3. Tap the notification.
4. Open the Push tab.

**Expected:**
- Push tab status shows `Push notification opened: <title>`.

*Result:* Pass
*Notes:* [Android] ProxyFriendly_36 emulator, Android 16 (API 36), arm64. DEVIATIONS (local harness only, uncommitted): (1) example AGP aligned to 8.11.0 so the includeBuild of the #615 SDK resolves; (2) example manifest removes firebase_messaging's `FlutterFirebaseMessagingService` (`tools:node=remove`) because it won MESSAGING_EVENT over `KlaviyoFlutterPushService` and no notification was built, so the cold-tap path could not be reached otherwise (see report: this is an example-app config issue). Process killed with `am kill` while backgrounded (force-stop blocks FCM). Push via the fcm-push-cli helper with a data-only payload. Tapped the notification with pid gone: Dart log `Native push notification event: {type: push_notification_opened, data: {body: chunk D open 90864, ...}}`, Push tab (opened afterwards, late subscriber) showed `Push notification opened: ChunkD open`.

---

### TC-007 — Android cold-start action-button tap reaches Dart

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- As TC-006. Payload has `action_buttons`.

**Steps:**
1. Force-stop the app.
2. Send the push, expand it, tap an `open_app` / `deep_link` action button.

**Expected:**
- `onPushAction` logs `Push action button tapped — id: …`.

*Result:* Pass
*Notes:* [Android] Same device and harness deviations as TC-006. Process killed, notification expanded, tapped `Open App` button. Dart log: `Native push action event: push_action_button_tapped` then `Push action button tapped — id: com.klaviyo.chunkd.open_app, action: open_app` (one action event). Also logged: a `MissingRegistration` warning from `Klaviyo.handlePush` called by the plugin before init ("operation will be retried"); `$opened_push` was enqueued after init, so non-fatal.

---

### TC-008 — Android Recents relaunch after a tap doesn't replay the old open

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android
- **Automation:** mobile-mcp + adb

**Preconditions:**
- TC-006 done once.

**Steps:**
1. Kill the process (`adb shell am kill` / swipe away then force-stop), keep it in Recents.
2. Relaunch from Recents.

**Expected:**
- No `push_notification_opened` is delivered on the relaunch.

*Result:* Pass
*Notes:* [Android] Same device/harness as TC-006/010. Cold tap opened the app (pid 3723, 1 open event). Then Home, `am kill` (pid gone), reopened from Recents card: new pid 3828, MainActivity focused, 0 `push_notification_opened` events in logcat after relaunch. CAVEAT: no `Not emitting push open for intent relaunched from history` line appeared (verbose), so I can't prove the FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY guard is what suppressed it; the relaunch intent may simply not have carried push extras (example now opts into the trampoline, so the task base intent is a plain launcher intent). Treat as 'no stale replay observed', not proof of the guard.

---

### TC-009 — Android secondary engine doesn't steal main-engine events

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + adb + fcm-push-cli

**Preconditions:**
- Example has `FirebaseMessaging.onBackgroundMessage` (second engine). App in background with the UI engine alive.

**Steps:**
1. Send a silent Klaviyo push (`_k`, no title/body) so the background isolate engine starts and later detaches.
2. Return to the app and confirm silent-push alert and token events still reach the main engine.
3. Send a normal push, tap it, confirm the open reaches the Push tab.
4. Trigger a form event if a forms flow is available.

**Expected:**
- Main engine keeps push, forms and JWT events after the secondary engine attaches and detaches.

*Result:* Pending
*Notes:* [Android] PARTIAL, not a full pass. App live and backgrounded (pid 3828). Silent Klaviyo push (`_k` only): `FLTFireBGExecutor: Creating background FlutterEngine instance` (second engine), `KlaviyoFlutterPushService: Silent push received: forwarding`, background isolate printed `Background silent push: null`, and the MAIN engine's Dart still received `silent_push_received` (`Silent push received: {_k: ...}`). Then a normal push tapped afterwards: MAIN engine received `push_notification_opened` (`chunk D open 68228`). So push events kept flowing to the main engine with a second engine present. NOT verified: forms events and JWT/auth events (not exercised), and I did not observe the secondary engine detaching (no detach log), so the attach-then-detach half of #189 is unproven on device. Cannot attribute to #189 alone: no baseline run without #189.

---

### TC-010 — Android cold web-link push tap records Opened Push natively

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + adb logcat + Klaviyo test profile events

**Preconditions:**
- App initialized once (API key persisted), force-stopped. Push carries an `https` URL.

**Steps:**
1. Send a push with a web link.
2. Tap it to cold-launch through the trampoline.
3. Check logcat for the SDK's Opened Push tracking and the test profile's events (read-only).

**Expected:**
- Opened Push is tracked natively. No Dart event is expected (MAGE-1576).

*Result:* Pass
*Notes:* [Android] Same device/harness as TC-006, plus local manifest opt-in `com.klaviyo.push.automatic_push_open_tracking=true` in the example so taps route through `KlaviyoTrampolineActivity` (without it the trampoline is not used). API key persisted from a prior session; process killed (pid gone) before the tap. logcat on tap: trampoline process started (`Start proc ... KlaviyoTrampolineActivity`), `KlaviyoTrampolineActivity$Companion: Automatically initialized Klaviyo from push open`, `KlaviyoApiClient: Enqueuing $opened_push event`, `Create Event Request enqueued`, `Trampoline dispatching external intent`; Chrome took focus. CAVEAT: the event POST then failed (`CertPathValidatorException: Trust anchor for certification path not found`, emulator has a proxy CA), so the request sits in the retry queue. Verified: tracked and enqueued natively on a cold start. NOT verified: that Klaviyo's server received `Opened Push` for the test profile (did not query the profile).

---

### TC-011 — Warm-start open still delivered once (regression)

- **Area:** Push
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp

**Preconditions:**
- App running with the Push tab open.

**Steps:**
1. Send a push, tap it while the app is backgrounded.

**Expected:**
- Push tab status updates once; no duplicate on re-subscribing beyond the held replay.

*Result:* Pending
*Notes:* [iOS] Warm path: app foregrounded on Push tab, `simctl push` plain push, tapped banner: status changed to `Push notification opened: Unknown` (live delivery works). Duplicate/once-only behavior NOT verified (my log stream was empty for this run, so I have no count). [Android] After TC-009's silent push, a normal push tapped while the app was alive and backgrounded produced exactly one `push_notification_opened` in the main engine's Dart log (no duplicate seen). Duplicate-on-resubscribe not checked.

---
