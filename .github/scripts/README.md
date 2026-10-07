# Example app publishing

`.github/workflows/publish-example.yml` builds the example app and ships it to the
Play internal track and TestFlight on pushes to `master` and `rel/**` and on
published GitHub releases. It does nothing on those triggers until the repo
variable `EXAMPLE_APP_PUBLISH_ENABLED` is `true`. `workflow_dispatch` ignores the
variable, so you can try a deploy by hand before switching it on.

Pull requests that touch the publish files get a dry run: shellcheck, the offline
tests in `tests/test-publish-scripts.sh`, and unsigned release builds on both
platforms. Dry runs use no secrets.

## Scripts

- `play-publish.sh`: Play Developer API client. Picks the highest versionCode
  Play has seen plus one, builds, uploads, and releases to the track. If Play
  rejects the upload or the edit commit because the versionCode is taken, it
  asks Play for the floor again, rebuilds and retries (3 attempts).
- `testflight-publish.sh`: build + `altool` upload loop ported from
  `klaviyo-ios-test-app`. On a duplicate build number it retries with
  `previousBundleVersion + 1`, or asks App Store Connect for latest + 1 when
  altool doesn't report the number.
- `asc.rb`: App Store Connect API helper (next build number, TestFlight
  "What to Test"). Standard library only.
- `release-notes.sh`: store release notes with the SDK version, commit and UTC
  build date, followed by the GitHub release body or, failing that, the commit
  subject.

## One-time setup (humans)

Store listings and config:

1. Play Console app for `com.klaviyo.flutterexample`, with an internal testing
   track and testers list. Play only accepts API uploads after the first
   bundle has been uploaded by hand, and rejects `completed` releases until
   the app has rolled out once; set the repo variable `PLAY_RELEASE_STATUS` to
   `draft` until then.
2. Google Cloud service account with release permissions on that app in Play
   Console (Users and permissions).
3. App Store Connect app for bundle id `com.klaviyo.FlutterExample` (team
   `G3793W2RJ2`), plus explicit App IDs for it and
   `com.klaviyo.FlutterExample.NotificationServiceExtension` with Push
   Notifications, App Groups (`group.com.klaviyo.FlutterExample`) and
   Associated Domains enabled.
4. App Store distribution profiles named `match AppStore com.klaviyo.FlutterExample`
   and `match AppStore com.klaviyo.FlutterExample.NotificationServiceExtension`
   added to `klaviyo/mobile-certificates` (run `fastlane match appstore` from
   `example/ios` once with write access; CI only reads).
5. Firebase project with an Android app for `com.klaviyo.flutterexample`. The
   example only initializes Firebase on Android, so iOS needs no
   `GoogleService-Info.plist`.

Repository secrets:

- `GOOGLE_SERVICES_JSON`: real `google-services.json` contents
- `SIGNING_KEY`: base64 of the upload keystore (`.jks`)
- `ALIAS`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`: upload key alias and passwords
- `SERVICE_ACCOUNT_JSON`: Play service account key JSON
- `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY_BASE64` (base64 of the `.p8`): App Store Connect
  API key with App Manager access
- `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`: decryption password and read-only deploy
  key for `klaviyo/mobile-certificates`
- `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`: password-protected `.p12` of the
  shared distribution certificate (works around macOS 26 rejecting match's
  empty-password import)
- `APPLE_TEAM_ID` (optional, defaults to `G3793W2RJ2`)
- `SLACK_WEBHOOK_URL`: incoming webhook for the publish channel (the step is
  skipped with a warning when unset)

Repository variables:

- `EXAMPLE_APP_PUBLISH_ENABLED=true` to turn on automatic deploys
- `PLAY_RELEASE_STATUS=draft` until the first Play release is rolled out

Consider putting the store secrets in a GitHub environment with branch
restrictions, so a workflow edited in a pull request can't read them.

## Public build logs

This repo is public, so anyone can read the Actions logs. The scripts never echo
secrets or run with `set -x`, and Slack only gets links that need a Play tester
or App Store Connect login to open. Do not add steps that print environment
variables, upload signed artifacts, or post public TestFlight links.
