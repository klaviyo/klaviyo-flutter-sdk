# Chunk E2: Android web-link taps on the final linear push stack (Flutter 1.0)

**Target:** Flutter SDK rel/0.6.0 + #199 stack (#187, #189, #198, #199 at 4e35453) + #185 (local merge `ecm/test/chunk-e2`, never pushed); Android SDK #615 linked locally (c6b26e7e06)
**Source:** klaviyo-flutter-sdk#187, #189, #198, #199, #185; klaviyo-android-sdk#615
**Author:** Claude drone, 2026-11-07
**Linear:** MAGE-548
**Linear Doc:** none

## Prerequisites

- [x] Android emulator ProxyFriendly_36 (Android 16, API 36); stale http_proxy cleared; fresh install and fresh FCM token.
- [x] Key LuYLmF only. Tokens never logged (length/hash only).
- [x] No manual removal of `FlutterFirebaseMessagingService`; the merged manifest from #185 is used as is.
- [x] Local probes: A and B subscribers at install, late subscriber L at +10s, deprecated listeners.

## Test Cases

### TC-001 — Warm web_url body tap

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

**Expected:**
- `onPushOpened` once with tap=webUrl and webUrl set; deprecated `onPushAction` once; browser opens.

*Result:* Pass
*Notes:* [Android] App backgrounded and alive, `web_url` push, tapped body. `opened[A]/[B]/[L]` each once: tap=webUrl webUrl=https://www.klaviyo.com. Deprecated onPushNotification once, deprecated onPushAction OpenWebUrl once. Chrome in foreground. `$opened_push` enqueued once.

---

### TC-002 — Warm "Open Site" (open_url) action button

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

**Expected:**
- `onPushOpened` once; deprecated `onPushAction` once; browser opens.

*Result:* Pass
*Notes:* [Android] `opened[A]/[B]/[L]` each once with tap=actionButton, button id com.klaviyo.chunke.url, action open_url, webUrl=https://www.klaviyo.com. Deprecated onPushAction ActionButtonTapped once. Chrome opened. Deviation from the brief's wording: tap is `actionButton` (not `webUrl`) for a button tap; `webUrl` is populated. This matches the model docs (`webUrl` tap kind = notification body only; a button carries its URL in `webUrl`).

---

### TC-003 — Cold web-link tap (app killed)

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

**Expected:**
- No Dart event. Native `$opened_push` enqueued via the #615 trampoline.

*Result:* Pass
*Notes:* [Android] Process confirmed dead (`pidof` empty), push `web_url`, tapped body. Zero Flutter-side CHUNKE lines. Log: `KlaviyoTrampolineActivity: Automatically initialized Klaviyo from push open`, `Enqueuing $opened_push event`, `Trampoline dispatching external intent`. Chrome opened.

---

### TC-004 — Regressions

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

*Result:* Pass
*Notes:* [Android] (a) Cold body tap (open_app): `opened[A]/[B]` once at launch, deprecated onPushNotification once; native 'Flutter not ready. Caching notification open event.' (b) Cold action button 'Open App': A and B once each, deprecated onPushNotification and onPushAction ActionButtonTapped once. (c) Held cold open replayed to A, B and late L (+10s) for both the body and the button tap. (d) The firebase_messaging background engine ('FLTFireBGExecutor: Creating background FlutterEngine instance') was alive in the cold-start process and in the foreground run; main-engine events still arrived once. (e) Landscape then portrait with app foregrounded, then body tap: A, B, L once each.

---

### TC-005 — Killed app: Klaviyo push displayed with firebase_messaging installed, no manual manifest edit

- **Area:** Push
- **Priority:** P0
- **Platforms:** Android

*Result:* Pass
*Notes:* [Android] Merged manifest lists `KlaviyoFlutterPushService` (MESSAGING_EVENT) before `FlutterFirebaseMessagingService`; no priority attribute. `pm` resolver table for MESSAGING_EVENT: KlaviyoFlutterPushService, FlutterFirebaseMessagingService, FirebaseMessagingService (in that order). With the app process dead, two pushes were each displayed (notification record for the app present, `contentIntent` startActivity, actions 'Open App' and 'Open Site' built from `action_buttons`). Caveat: no `KlaviyoPushService` log line appeared for the cold push (logging not initialized in a cold process), so "Klaviyo built it" is inferred from the Klaviyo-style action buttons and tap handling, not a log line. In the cold process FlutterFirebaseMessagingReceiver also ran and created the background engine.

---
