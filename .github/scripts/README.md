# Example app publishing

`.github/workflows/publish-example.yml` builds the example app and ships it to the Play internal track and
TestFlight on pushes to `master` and `rel/**`, on published GitHub releases, from `workflow_dispatch`, and from a
same-repo PR labeled `deploy-example-app` (both), `deploy-example-app:android` or `deploy-example-app:ios` (the label
is removed after the run). Unit tests and lint must pass first. A push or release with missing secrets ends green
with a notice naming them; a manual or label deploy fails. `workflow_dispatch` with `check_credentials` verifies each
platform's credentials without building or uploading.

## Scripts

- fastlane (`example/ios/fastlane`, `example/android/fastlane`) does the signing, build number, upload and store
  notes. iOS lanes: `install_signing`, `release`, `whats_new`, `next_build_number`. Android lanes: `release`,
  `share` (Internal App Sharing link), `check_credentials`. Both retry an upload once with a fresh build number
  or versionCode.
- `app-version.sh`: derives the app version from the SDK version and build number (`X.Y.Z` on a release, `X.Y.Z-rc.N` on `rel/*`, `X.Y.Z-alpha.N` otherwise); fails when it cannot. Android `versionName` and the in-app, notes and Slack text use the full string; iOS `CFBundleShortVersionString` stays `X.Y.Z` and the full string goes in the `KlaviyoAppVersion` Info.plist key.
- `release-notes.sh`: store release notes (build info header, CI run line, release body on release events).
- `gradle-retry.sh`: retries the Android build with `--refresh-dependencies` on a JitPack failure.
- `source-label.sh`: release tag, PR head branch, or branch name, shown in notes and Slack.
- `check-secrets.sh`: preflight; prints only the names of missing secrets.
- `slack-payload.sh`: builds the Slack message as JSON.
- `scripts/sdk-ref.sh` (repo root): writes `example/build-info.json` (SDK refs, commit, branch, source) that the
  builds embed and the app shows in its Build info sheet.

## One-time setup (humans)

1. Play Console app for `com.klaviyo.flutterexample` with an internal testing track and testers. The first bundle
   must be uploaded by hand; set the repo variable `PLAY_RELEASE_STATUS=draft` until the app has rolled out once.
2. Play service account with release permissions on that app.
3. App Store Connect app for `com.klaviyo.FlutterExample` (team `G3793W2RJ2`) plus App IDs for it and
   `com.klaviyo.FlutterExample.NotificationServiceExtension` (Push Notifications, App Groups
   `group.com.klaviyo.FlutterExample`, Associated Domains).
4. Profiles `match AppStore com.klaviyo.FlutterExample` and
   `match AppStore com.klaviyo.FlutterExample.NotificationServiceExtension` in `klaviyo/mobile-certificates`.
5. Firebase Android app for `com.klaviyo.flutterexample`.

Repository secrets (not environment secrets; the preflight cannot see those):

- `GOOGLE_SERVICES_JSON`, `SIGNING_KEY` (base64 keystore), `ALIAS`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`,
  `SERVICE_ACCOUNT_JSON`
- `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`
- `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`
- Optional: `SLACK_WEBHOOK_URL`, `APPLE_TEAM_ID` (defaults to `G3793W2RJ2`)

Deploy jobs run in the `android-internal-track` and `testflight` environments, with no required reviewers.

The repo is public, so Actions logs are too: never echo secrets or enable `set -x`.
