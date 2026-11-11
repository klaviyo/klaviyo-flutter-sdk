# Chunk E: typed push streams + chunk D re-run (Flutter 1.0)

**Target:** Flutter SDK rel/0.6.0 + #187 + #189 + #198 + #199 + #184 + #185 (local merge `ecm/test/chunk-e`, never pushed); Android SDK #615 linked locally (base rel/4.6.1)
**Source:** klaviyo-flutter-sdk#187, #189, #198, #199, #184, #185; klaviyo-android-sdk#615 (MAGE-548, MAGE-1034, MAGE-1481, MAGE-1576, MAGE-1574, MAGE-1060, MAGE-1582)
**Author:** Claude drone (test-plan design), 2026-11-07
**Linear:** MAGE-548
**Linear Doc:** none

## Prerequisites

- [ ] One device at a time. iOS simulator first, shut down, then Android emulator.
- [ ] Example built from worktree `.claude/worktrees/ecm-test-chunk-e` (never pushed).
- [ ] Test API key LuYLmF only. Never TRJ3wp. Server reads UNVERIFIED; evidence is native + Dart logs.
- [ ] Local-only probe file `example/lib/chunke_probes.dart`: subscribers A and B at install, late subscriber L at +10s, plus deprecated `onPushNotification` / `onPushAction` listeners, `onPushToken` (logs length/hash only) and `onPushData`. All log lines prefixed `CHUNKE`.
- [ ] iOS: `xcrun simctl push` (no NSE; local test category `chunke.actions` in AppDelegate), ad-hoc signed build for aps-environment.
- [ ] Android: fcm-push-cli with existing config, data-only payloads; `FlutterFirebaseMessagingService` removed in the example manifest so Klaviyo builds the notification (same as chunk D); android-sdk #615 linked via includeBuild with AGP 8.11.0.
- [ ] Tokens never printed; saved logs scrubbed.

## Test Cases

### TC-001 — onPushOpened: exactly one event for a body tap (warm and cold)

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + simctl / fcm-push-cli

**Preconditions:**
- SDK initialized; probes installed.

**Steps:**
1. Warm: app foregrounded or backgrounded, deliver a push, tap the body.
2. Cold: terminate the app, deliver a push, tap the body, wait for init.

**Expected:**
- Exactly one `opened[A]` line (tap=notification) per tap; one `opened[B]` line.
- Cold: event carries `replayed=true`.

*Result:* Pass
*Notes:* [iOS] iPhone 17 Pro sim iOS 26.5, ad-hoc signed Debug build, key LuYLmF. Body tap, warm: one onPushNotification, opened[A], opened[B], opened[L] each once. Cold (terminated, tap banner): native 'Flutter not ready. Caching notification open event.'; at launch opened[A]/[B] and deprecated onPushNotification once each; L (+10s) got it once. Payload replayed=null on iOS (no replayed marker on iOS). Android pending. | [Android] Pixel-class emulator (ProxyFriendly_36) Android 16 API 36, debug build, android-sdk #615 via includeBuild, FCM data-only via fcm-push-cli, key LuYLmF. Body tap warm: one opened[A]/[B]/[L] + one deprecated onPushNotification. Cold (am kill): native 'Flutter not ready. Caching notification open event.', A and B once at launch, L once at +10s. Foreground app also fine. replayed marker is stripped by the Dart wrapper, so it is not visible in the payload.

---

### TC-002 — onPushOpened: exactly one event for an action-button tap (warm and cold)

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + simctl category / fcm-push-cli action_buttons

**Steps:**
1. Warm: deliver a push with action buttons, tap a button.
2. Cold: terminate, deliver, tap a button.

**Expected:**
- One `opened[A]` per tap with tap=actionButton and the button id and action.

*Result:* Pass
*Notes:* [iOS] Action 'Open App' tap (local category chunke.actions + body.action_buttons in payload, no NSE): warm and cold each give one opened[A]/[B] (tap=actionButton, button id+open_app), one deprecated onPushNotification and one deprecated onPushAction ActionButtonTapped. Cold: late L got it once at +10s. Android pending. | [Android] Open App button: warm one event per stream (opened A/B/L tap=actionButton, deprecated onPushNotification, deprecated onPushAction ActionButtonTapped). Cold: Caching open + Caching push action natively, then A, B, deprecated onPushNotification and onPushAction once each; L once at +10s.

---

### TC-003 — onPushOpened: exactly one event for a web-URL tap (iOS, warm and cold)

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS
- **Automation:** mobile-mcp + simctl

**Steps:**
1. Warm and cold: push with an `open_url` button (or `web_url`), tap it.

**Expected:**
- One `opened[A]` with tap=webUrl and webUrl set.

*Result:* Pass
*Notes:* [iOS] web_url body tap: warm and cold each one opened[A]/[B] tap=webUrl webUrl=https://www.klaviyo.com, one deprecated onPushAction OpenWebUrl, one deprecated onPushNotification. | [iOS] final: warm and cold web_url body taps each give one onPushOpened (tap=webUrl) on iOS. Android web-link taps are TC-010 (Fail).

---

### TC-004 — Held cold-start open replays to a late subscriber and to two subscribers

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp

**Steps:**
1. Terminate, deliver push, tap, launch.
2. Watch A, B (at install) and L (10s later).

**Expected:**
- A and B each get the held open (`replayed=true`); L, attaching later, behaves as designed and is recorded as observed.

*Result:* Pass
*Notes:* [iOS] Cold body, action and web taps: A and B both receive the held open at launch; late L (attached 10s later) also receives it once. Android pending. | [Android] Cold body and cold action tap: A and B get held open at launch; L (+10s) also gets it once.

---

### TC-005 — onPushToken emits a token

- **Area:** Push
- **Priority:** P1
- **Platforms:** iOS, Android

**Steps:**
1. Enable push from the Push tab.

**Expected:**
- `CHUNKE token len=<n>` line; the token is never printed.

*Result:* Pending
*Notes:* [iOS] UNVERIFIED: no push token in the simulator (no APNs registration), no CHUNKE token line emitted. Android pending. | [Android] Pass: after granting POST_NOTIFICATIONS via the Push tab, 'CHUNKE token len=142 hash=<redacted>' once. Token never printed. iOS stays UNVERIFIED (simulator has no APNs token).

---

### TC-006 — onPushData fires for a silent push in the foreground

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android, iOS
- **Automation:** fcm-push-cli silent payload (Android); simctl content-available (iOS, UNVERIFIED if not deliverable)

**Expected:**
- `CHUNKE data keys=[...]` once.

*Result:* Pending
*Notes:* [iOS] UNVERIFIED: 3 simctl payloads (content-available silent, silent + key_value_pairs, visible + content-available + key_value_pairs) in foreground never produced native 'Silent push received' nor a CHUNKE data line, so didReceiveRemoteNotification was not invoked by simctl (simulator limitation). Android pending. | [Android] Pass: data-only silent push in foreground gives one 'CHUNKE data keys=[_k,key_value_pairs]' (plus one deprecated onPushNotification type=silent_push_received). Backgrounded silent push also reaches onPushData. iOS UNVERIFIED (see above).

---

### TC-007 — Visible push with key/value pairs: onPushData on arrival (foreground), onPushOpened on tap

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android, iOS

**Expected:**
- `data` line on arrival, then one `opened[A]` on tap.

*Result:* Pending
*Notes:* [iOS] UNVERIFIED for onPushData on arrival (same simctl limitation); onPushOpened on tap verified (see TC-001). Android pending. | [Android] Pass: visible push with key_value_pairs in foreground: one onPushData on arrival (keys include title/body/key_value_pairs), then on tap one opened[A]/[B]/[L]. iOS: onPushOpened verified, onPushData UNVERIFIED (simctl).

---

### TC-008 — Deprecated onPushNotification and onPushAction still work

- **Area:** Push
- **Priority:** P1
- **Platforms:** iOS, Android

**Expected:**
- Deprecated listeners log for a body tap (`onPushNotification`) and an action/web tap (`onPushAction`).

*Result:* Pass
*Notes:* [iOS] deprecated onPushNotification fires once per tap for body/action/web; deprecated onPushAction fires once for action-button and web-url taps (not for body tap). Android pending. | [Android] deprecated onPushNotification once per tap (body/action/kv); deprecated onPushAction once for Open App button and once for the web link (OpenWebUrl); none for plain body tap. Both platforms work.

---

### TC-009 — flutter analyze on the example shows no errors

- **Area:** Init
- **Priority:** P1
- **Platforms:** Flutter

**Expected:**
- No errors.

*Result:* Pass
*Notes:* `flutter analyze` in `example/` (before the local probe file): 2 issues, both `experimental_member_use` warnings (`KlaviyoPushData` main.dart:96, `onPushData` main.dart:145). Zero errors. Warnings are in the example's own use of the `@experimental` API. | [Flutter] with the local probe file added: 0 errors; infos are trailing-comma lints in the probe file only.

---

### TC-010 — #198: warm Android web-link tap reaches onPushAction and onPushOpened once each; cold tap gives no Dart event

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android
- **Automation:** mobile-mcp + fcm-push-cli

**Steps:**
1. Warm: push with `open_url` button or `web_url`, tap.
2. Cold: terminate, same push, tap, then wait.

**Expected:**
- Warm: one `deprecated onPushAction` and one `opened[A]` (tap=webUrl).
- Cold: no Dart event; native log shows Opened Push recorded (#615).

*Result:* Fail
*Notes:* [Android] FAIL (P0 blocker posted). Warm web-link tap, both the 'Open Site' open_url button and a web_url body tap: deprecated onPushAction fires once (OpenWebUrl / ActionButtonTapped path), but onPushOpened fires ZERO times and the deprecated onPushNotification does not fire either. Chrome opens. Likely cause: #198's observer feeds only the push-action controller; #199 builds onPushOpened from push_notification_opened events only; #198 and #199 are siblings off #187 so they are not combined. Cold web-link tap: no Dart event (as expected); trampoline log 'Automatically initialized Klaviyo from push open' + 'Enqueuing $opened_push event' + 'dispatching external intent' (Opened Push recorded natively through #615). Note the iOS web tap does give onPushOpened once (tap=webUrl).

---

### TC-011 — Re-run D TC-003 against reworked #189: two subscribers both get the held event

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS, Android

**Expected:**
- A and B both log the held open.

*Result:* Pass
*Notes:* [iOS] Two subscribers (A,B) both got the held cold-start open for body, action and web taps. Android pending. | [Android] Two subscribers A and B both received the held cold-start open (body and action), plus late L. Reworked #189 holds the event process-wide; delivery to the primary engine confirmed.

---

### TC-012 — Android secondary engine (firebase_messaging background isolate) does not steal main-engine events

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

**Steps:**
1. Launch app (the `onBackgroundMessage` handler creates a second engine on first push while backgrounded).
2. Deliver push, tap; deliver silent push in foreground.
3. If the example can trigger forms or JWT events, check them.

**Expected:**
- Opens and data events still reach the main engine's A/B listeners once.

*Result:* Pass
*Notes:* [Android] firebase_messaging onBackgroundMessage creates a second FlutterEngine (log 'FLTFireBGExecutor: Creating background FlutterEngine instance', handler printed 'Background silent push'). With it alive: main engine still got the silent push (onPushData once) and the next body tap (opened A/B/L once each). Forms/JWT events: UNVERIFIED, not triggered (no safe trigger without server-side forms in LuYLmF).

---

### TC-013 — Rotate the device while foregrounded, then a push open reaches the main engine

- **Area:** Push
- **Priority:** P1
- **Platforms:** Android

**Steps:**
1. Rotate to landscape and back with the app foregrounded.
2. Deliver push, tap.

**Expected:**
- One `opened[A]`.

*Result:* Pass
*Notes:* [Android] Rotated landscape then portrait with the app foregrounded (topResumedActivity MainActivity), then a push body tap: opened[A]/[B]/[L] once each and deprecated onPushNotification once.

---

### TC-014 — iOS secondary engine (temporary local FlutterEngine in AppDelegate)

- **Area:** Push
- **Priority:** P2
- **Platforms:** iOS

**Expected:**
- Opens still reach the main engine; or UNVERIFIED with reason.

*Result:* Pass
*Notes:* [iOS] Temporary FlutterEngine 'chunke-secondary' (no-op Dart entrypoint, plugins registered) created in AppDelegate before the main engine. Log 'CHUNKE secondary engine started' + 'secondary entrypoint running'. Warm and cold body taps still reached main-engine A/B/L exactly once each.

---

### TC-015 — iOS swipe-dismiss sends no open event

- **Area:** Push
- **Priority:** P0
- **Platforms:** iOS

**Steps:**
1. Deliver a push with the customDismissAction category, swipe it away (app foregrounded/backgrounded, then launched cold).

**Expected:**
- No `opened` or deprecated open lines.

*Result:* Pass
*Notes:* [iOS] Category has customDismissAction. Swiped the notification away from Notification Center (cold app and warm): native log 'Push notification dismissed' (cold), no Dart open event; after launch + 10s late subscriber L attached and got nothing (no replay). Banner swipe via mobile-mcp didn't register on the live banner; used the lock-screen stack instead.

---
