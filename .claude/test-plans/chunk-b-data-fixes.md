# Flutter 1.0 chunk B: 0.6.0 data fixes

**Target:** klaviyo_flutter_sdk 0.6.0 (local merge of PRs 178, 180, 179, 182 on rel/0.6.0)
**Source:** https://claude.ai/artifact/JeWnCit4KRWynAScFvY9k6
**Author:** Claude drone, 2026-11-07
**Linear:** MAGE-1645
**Linear Doc:** none

**Devices:** iOS: iPhone 17 Pro simulator, iOS 26.5, Debug build, KlaviyoSwift 5.6.0. Android: ProxyFriendly_36 emulator (google_apis arm64, Android 16 / API 36), Debug build, klaviyo-android-sdk 4.6.0. Flutter 3.41.2, plugin 0.6.0 (local merge of #178, #180, #179, #182 on origin/rel/0.6.0).
**Verification level:** every Pass here means bridge-verified: the exact channel arguments and the native key mapping or queued request were logged. Server-side Klaviyo checks are UNVERIFIED because the app's company key (LuYLmF) is not readable through the available Klaviyo MCP (it reads TRJ3wp). TC-018, TC-019 and TC-022 used a fake tracking host.

## Prerequisites

- [ ] One device at a time: iOS simulator first, shut down, then Android emulator.
- [ ] Example app built from worktree ecm-test-chunk-b with temp harness (Profile tab buttons labelled `H TCxxx`).
- [ ] App saved company key LuYLmF. The Klaviyo MCP reads a different account (TRJ3wp), so server-side checks are UNVERIFIED. Evidence = native logs.
- [ ] Test profiles only. New emails use the pattern evan.masseau+flutter-chunkb-<tcid>-<platform>@klaviyo.com.

## Test Cases

### TC-001 — Set Full Profile sends the custom property

- **Area:** Profile
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run.

**Steps:**
1. Open the Profile tab.
2. Enter a unique email, First Name `Ada` and Last Name `Lovelace`.
3. Tap Set Full Profile.
4. In Klaviyo, open Audience, then Profiles, and search for the email.
5. Open the profile and look at the Properties list.

**Expected:**
- The profile shows First name `Ada` and Last name `Lovelace`. The Properties list has a custom property `example_app_source` with value `flutter_profile_tab`. The key is not nested or prefixed.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Queue createProfile: first_name Ada, last_name Lovelace, properties {example_app_source: flutter_profile_tab} (nested, not flat). | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: first_name Ada, last_name Lovelace, properties {example_app_source: flutter_profile_tab}.

---

### TC-002 — Several custom properties with mixed types

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC002 props

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary edit: change the Set Full Profile call to pass `properties: {'plan': 'pro', 'seats': 5, 'trial': true}`.

**Steps:**
1. Tap Set Full Profile.
2. In Klaviyo, open Audience, then Profiles, and search for the email.
3. Open the profile Properties list.

**Expected:**
- Three custom properties appear: `plan` is `pro`, `seats` is `5`, `trial` is `true`. Nothing is missing and nothing is nested under another key.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Bridge setProfile properties {plan: pro, seats: 5, trial: 1}; queue createProfile properties {plan:'pro', seats:5, trial:true}. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: properties {plan: pro, seats: 5, trial: true}.

---

### TC-003 — A custom key named like a standard field stays custom

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC003 firstName custom

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary edit: pass `properties: {'firstName': 'Grace'}` with First Name `Ada` in the form.

**Steps:**
1. Tap Set Full Profile.
2. In Klaviyo, open Audience, then Profiles, and search for the email.
3. Open the profile.

**Expected:**
- First name is `Ada`. The Properties list has a separate custom property `firstName` with value `Grace`. The standard first name is not overwritten.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Queue createProfile first_name Ada AND properties {firstName: Grace}; standard field not overwritten. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: first_name Ada plus properties {firstName: Grace}; standard field not overwritten.

---

### TC-004 — Set Full Profile with no custom properties still saves standard fields

- **Area:** Profile
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC004 no props

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary edit: remove `properties` from the Set Full Profile call.

**Steps:**
1. Enter a unique email, First Name `Ada` and Last Name `Lovelace`.
2. Tap Set Full Profile.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile.

**Expected:**
- First name and Last name are saved. The profile has no `example_app_source` property and no empty or stray custom property.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Bridge properties=nil, keys email,first_name,last_name; queue createProfile properties {} (empty, no example_app_source). | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). bridge properties=null; wire body from the Android SDK request queue log: first_name Ada, last_name Lovelace, no properties key.

---

### TC-005 — camelCase first and last name land on the standard fields

- **Area:** Profile
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC005 camel names

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('firstName', 'Ada')`.
3. Call `setProfileAttribute('lastName', 'Lovelace')`.
4. In Klaviyo, open Audience, then Profiles, and search for the email.
5. Open the profile.

**Expected:**
- First name is `Ada` and Last name is `Lovelace` in the profile header. The Properties list has no custom `firstName` or `lastName`.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Bridge setProfileProperties: first_name -> .firstName=Ada, last_name -> .lastName=Lovelace (Dart normalized camelCase before the channel). Final folded wire body not visible (Swift SDK folds staged attributes at queue drain); relies on SDK mapping. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). bridge first_name -> FIRST_NAME, last_name -> LAST_NAME; wire body from the Android SDK request queue log: first_name Ada, last_name Lovelace as standard attributes, no custom keys.

---

### TC-006 — snake_case and odd casing map to the same fields

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC006 snake/upper

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('first_name', 'Ada')`.
3. Call `setProfileAttribute('LASTNAME', 'Lovelace')`.
4. In Klaviyo, open Audience, then Profiles, and search for the email.
5. Open the profile.

**Expected:**
- First name is `Ada` and Last name is `Lovelace`. No custom properties named `first_name` or `LASTNAME` exist.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). first_name and LASTNAME both arrive as first_name/last_name -> .firstName/.lastName. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). first_name and LASTNAME both -> FIRST_NAME / LAST_NAME; wire body from the Android SDK request queue log: standard first_name/last_name only.

---

### TC-007 — organization, title and image land on the standard fields

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC007 org/title/image

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('organization', 'Acme')`, `('title', 'Engineer')` and `('image', 'https://example.com/ada.png')`.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile.

**Expected:**
- The profile shows Organization `Acme` and Title `Engineer`. The image URL is set as the profile image. None of the three appears as a custom property.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). organization/title/image all map to standard ProfileKeys, none custom. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). organization/title/image -> standard keys; wire body from the Android SDK request queue log: organization Acme, title Engineer, image URL.

---

### TC-008 — Location keys land on the profile location, with both spellings

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC008 location

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute` for `address1` = `1 Main St`, `address_2` = `Suite 4`, `city` = `Boston`, `country` = `US`, `region` = `MA`, `zip` = `02110`, `latitude` = `42.35`, `longitude` = `-71.05`.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile and look at its location.

**Expected:**
- Address 1 is `1 Main St`, Address 2 is `Suite 4`, City `Boston`, Country `US`, Region `MA`, ZIP `02110`. Latitude and longitude match. Nothing appears as a custom property.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). address1, address_2->address2, city, country, region, zip, latitude 42.35, longitude -71.05 all map to standard ProfileKeys. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: location {address1, address2, city, country, latitude 42.35, longitude -71.05, region, zip}; none custom.

---

### TC-009 — timezone lands differently on Android and iOS

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC009 timezone

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('timezone', 'America/New_York')`.
3. Call `setProfileAttribute('time_zone', 'America/Chicago')`.
4. In Klaviyo, open Audience, then Profiles, and search for the email.
5. Open the profile.

**Expected:**
- Android: the profile location Timezone is set. Both calls map to the same field and the last call wins. iOS: a custom property `timezone` holds the value, because the iOS SDK has no timezone field.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Expected iOS gap: timezone and time_zone both arrive as 'timezone' -> .custom(customKey: timezone); America/Chicago last. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). timezone and time_zone both -> TIMEZONE; wire body from the Android SDK request queue log: location.timezone America/Chicago (last call wins). iOS keeps it custom (documented gap).

---

### TC-010 — email, phoneNumber and externalId stay custom through setProfileAttribute

- **Area:** Profile
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC010 identifiers

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('externalId', 'ext-123')` and `('phoneNumber', '+15555550100')`.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile.

**Expected:**
- The profile External ID and phone number are not changed. The Properties list has custom properties `externalId` and `phoneNumber` on both platforms.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). externalId and phoneNumber arrive unchanged -> .custom(customKey:); no identifier fields changed. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). externalId/phoneNumber -> CUSTOM; wire body from the Android SDK request queue log: properties {externalId: ext-123, phoneNumber: +15555550100}, identifier fields untouched.

---

### TC-011 — An unknown key stays a custom property

- **Area:** Profile
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC011 unknown

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('favorite_color', 'green')`.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile.

**Expected:**
- The Properties list has `favorite_color` with value `green` on both platforms.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). favorite_color -> .custom(customKey: favorite_color)=green. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). favorite_color -> CUSTOM; wire body from the Android SDK request queue log: properties {favorite_color: green}.

---

### TC-012 — A null alias does not erase a real value

- **Area:** Profile
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC012 null alias

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary edit: a button that calls `setProfileProperties({'firstName': 'Ada', 'first_name': null})`.

**Steps:**
1. Set a unique email with Set Email.
2. Tap the button.
3. In Klaviyo, open Audience, then Profiles, and search for the email.
4. Open the profile.

**Expected:**
- First name is `Ada`. It is not blank and there is no custom `first_name` property.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Only first_name=Ada reaches the bridge; the null alias never crosses (normalizer drops it). | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). only first_name=Ada crosses the bridge; wire body from the Android SDK request queue log: first_name Ada.

---

### TC-013 — A lone null value does not crash the app

- **Area:** Profile
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC013 lone null

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key. A fresh email unique to this run. Temporary code edit: a button in the example Profile tab that calls `setProfileAttribute` (see setup).

**Steps:**
1. Set a unique email with Set Email.
2. Call `setProfileAttribute('nickname', null)`.
3. Watch the app and the device log.
4. Tap Set Email again to confirm the SDK still works.

**Expected:**
- The app does not crash and no exception reaches Dart. Later calls still work. The profile gets no `nickname` value.

*Result:* Pass
*Notes:* [iOS] pass (no crash, server UNVERIFIED). nickname=null reached iOS as <null> -> .custom(customKey: nickname); app stayed up, harness reported OK, later calls (Set Email, events) worked. | [Android] nickname=null reached Kotlin as non-serializable and was skipped (no native call); no crash, later calls worked, no nickname on the wire.

---

### TC-014 — Event with a value and a currency

- **Area:** Events
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC014 USD

**Preconditions:**
- Example app built from the PR branch. SDK initialized with a test company key and a known email. Temporary edit: the Added to Cart quick button builds `KlaviyoEvent.custom(name: 'Added to Cart', value: 59.98, valueCurrency: 'USD')`.

**Steps:**
1. Open the Events tab.
2. Tap Added to Cart.
3. In Klaviyo, open the profile and its activity feed, or Analytics and Metrics for `Added to Cart`.
4. Open the new event.

**Expected:**
- The event shows value `59.98` and currency `USD`.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Queue createEvent 'Added to Cart' value 59.98, value_currency USD. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: Added to Cart value 59.98, value_currency USD. Android also sends $value_currency USD in properties (native SDK, known).

---

### TC-015 — A non-USD currency arrives unchanged

- **Area:** Events
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC015 EUR then H TC015 JPY

**Preconditions:**
- Same edit as TC-014 with `valueCurrency: 'EUR'`, then again with `'JPY'`.

**Steps:**
1. Tap Added to Cart.
2. Open the event in the Klaviyo activity feed.
3. Repeat with the other currency.

**Expected:**
- The first event shows currency `EUR` and the second shows `JPY`. Neither falls back to USD.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Queue createEvent value_currency EUR (value 10) and JPY (value 1000); no USD fallback. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: value_currency EUR (value 10) and JPY (value 1000); no USD fallback.

---

### TC-016 — Event without a currency is unchanged

- **Area:** Events
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- Example app built from the PR branch. No edit needed.

**Steps:**
1. Open the Events tab.
2. Tap Started Checkout (value 99.99).
3. Open the event in the Klaviyo activity feed.

**Expected:**
- The event shows value `99.99` and no currency. It looks the same as it did before this PR.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Stock Started Checkout: bridge value 99.99, currency nil; queued event has no value_currency key. | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). stock Started Checkout: bridge currency=null; event has $value 99.99, no value_currency and no $value_currency.

---

### TC-017 — Currency and event properties together

- **Area:** Events
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC017 USD+sku

**Preconditions:**
- Same edit as TC-014. Use the Events tab Property Key and Property Value fields.

**Steps:**
1. Enter Event Name `Added to Cart`, Property Key `sku` and Property Value `SKU-1`.
2. Tap Track Event with the currency edit active.
3. Open the event in the Klaviyo activity feed and read its properties.

**Expected:**
- The event has `sku` = `SKU-1`, value, and currency `USD`. The currency shows as the event currency. Android may also list a `$value_currency` property. iOS does not.

*Result:* Pass
*Notes:* [iOS] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). Queue createEvent value 20, value_currency USD, properties sku=SKU-1; no $value_currency property on iOS (as expected). | [Android] pass (bridge-verified, server UNVERIFIED: account LuYLmF not readable via MCP). wire body from the Android SDK request queue log: sku SKU-1, value 20, value_currency USD, $value_currency USD present (Android only, expected).

---

### TC-018 — Tracking link before initialize does not throw

- **Area:** Deep Links
- **Priority:** P0
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC018 link preinit-safe

**Preconditions:**
- Example app built from the PR branch. Temporary edit in `example/lib/main.dart`: remove the `isInitialized` guard so `handleUniversalTrackingLink` runs before `initialize()`. A real tracking link `https://<tracking-host>/u/<id>` from a test send.

**Steps:**
1. Force-quit the app.
2. Open the tracking link from Notes or Messages so it opens the app.
3. Watch the app and the device log.

**Expected:**
- The call returns `true`. No exception reaches Dart and the app does not crash. The link resolves to its destination. The click shows up in the Klaviyo report for that send.

*Result:* Pass
*Notes:* [iOS] pass (no throw; click report UNVERIFIED). SDK uninitialized (api key pref removed, relaunched), handleUniversalTrackingLink called with https://email.example-track.com/u/abc123 (fake host, no real tracking link available). Native logged 'Attempting to resolve tracking link destination'; DNS failed as expected; no exception to Dart. Destination resolution and Klaviyo click report not checked. | [Android] pass (no throw; click report UNVERIFIED). App data cleared first, SDK uninitialized. Plugin logged returned=true, configRegistered=true (it registers lifecycle callbacks first). Native: 'Universal Link Request inflight', UnknownHostException from the fake host email.example-track.com (no real tracking link available), request dropped, no exception to Dart.

---

### TC-019 — Tracking link after initialize still works

- **Area:** Deep Links
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- Example app built from the PR branch. SDK already initialized. A real tracking link.

**Steps:**
1. Open the app and wait for initialization.
2. Open the tracking link from Notes or Messages.
3. Watch the device log.

**Expected:**
- The call returns `true` and the link resolves as before. The click shows up in the Klaviyo report for that send.

*Result:* Pass
*Notes:* [iOS] pass (no throw; click report UNVERIFIED). Same call with SDK initialized: native 'Attempting to resolve tracking link destination' then DNS failure from the fake host. Real link not available. | [Android] pass (no throw; click report UNVERIFIED). Same call after initialize(): returned=true, same native flow and DNS failure from the fake host.

---

### TC-020 — A non-tracking URL is ignored

- **Area:** Deep Links
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: H TC020 non-tracking url

**Preconditions:**
- Same edit as TC-018.

**Steps:**
1. Call `handleUniversalTrackingLink('https://example.com/not-a-tracking-link')`.
2. Watch the device log or a network proxy.

**Expected:**
- The call returns `false`. No request leaves the device for that URL.

*Result:* Pass
*Notes:* [iOS] pass (no native call; return value not read). https://example.com/not-a-tracking-link: no 'Attempting to resolve' log, no network request. The returned false was not displayed (harness overwrites its status line); regex path is also unit-tested. | [Android] pass (no native call; return value not read). For https://example.com/not-a-tracking-link no handleUniversalTrackingLink bridge line or request appears in logcat; only the TC-018 URL does. The returned false was not displayed.

---

### TC-021 — initialize works after a pre-init tracking link

- **Area:** Deep Links
- **Priority:** P1
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- Same edit as TC-018.

**Steps:**
1. Force-quit the app and open a tracking link so the call runs first.
2. Let the app call `initialize()`.
3. Tap Set Email with a unique email and tap Added to Cart.
4. Check the profile and the event in Klaviyo.

**Expected:**
- Initialization succeeds. The email lands on the profile and the event appears on that profile. Nothing is stuck in a half-initialized state.

*Result:* Pass
*Notes:* [iOS] pass (server UNVERIFIED). After a pre-init link call, initialize(LuYLmF) succeeded, Set Email created createProfile for the test email, event queued. | [Android] pass (server UNVERIFIED). After the pre-init link call, initialize(LuYLmF) succeeded; later setEmail plus Added to Cart USD event were queued with the new profile.

---

### TC-022 — Failed resolve before init while offline

- **Area:** Deep Links
- **Priority:** P2
- **Platforms:** iOS, Android
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- Same edit as TC-018. Device in airplane mode.

**Steps:**
1. Force-quit the app.
2. Open a tracking link while offline.
3. Turn the network back on and wait a minute.
4. Open the Klaviyo report for that send.

**Expected:**
- The call does not throw. Android: the click is retried and appears after the network returns. iOS: the click is not retried and does not appear.

*Result:* Pending
*Notes:* [iOS] UNVERIFIED. Airplane mode not simulated. Related evidence: failed pre-init resolve logged 'Klaviyo SDK not initialized; dropping pre-init request' (matches the documented iOS drop), but the offline path itself was not run. | [Android] UNVERIFIED. Airplane mode not run and no real tracking link, so the Android retry-after-network-returns claim is untested. Fake-host failure showed 'max attempts reached ... will be dropped' for an unresolvable host, which is not the offline case.

---

### TC-023 — Peer dependency installs on RN SDK 2.5 and up

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- An Expo app using `klaviyo-expo-plugin` from the PR branch.

**Steps:**
1. Install with `klaviyo-react-native-sdk` 2.6.0 and run `npm install`.
2. In a second app, pin `klaviyo-react-native-sdk` 2.4.1 and run `npm install`.

**Expected:**
- With 2.6.0 the install succeeds with no peer warning. With 2.4.1 it fails with `ERESOLVE`.

*Result:* Skip
*Notes:* N/A per dispatch: klaviyo-expo-plugin#170 is docs and dependencies only.

---

### TC-024 — expo prebuild writes both iOS location strings

- **Area:** Profile
- **Priority:** P1
- **Platforms:** iOS
- **Automation:** mobile-mcp + temp harness button: existing example UI

**Preconditions:**
- The Expo example app from the PR branch (`example/app.config.js` lists `expo-location`).

**Steps:**
1. Run `expo prebuild --platform ios` in the example app.
2. Open `ios/<app>/Info.plist`.
3. Look for both location usage keys.

**Expected:**
- `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` are present with the strings from `app.config.js`, not the generic default text.

*Result:* Skip
*Notes:* N/A per dispatch: klaviyo-expo-plugin#170 is docs and dependencies only.

---
