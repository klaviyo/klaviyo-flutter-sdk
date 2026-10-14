# Example app publishing

`.github/workflows/publish-example.yml` builds the example app and ships it to the
Play internal track and TestFlight on pushes to `master` and `rel/**` and on
published GitHub releases, and from a same-repo PR labeled
`deploy-example-app` (both), `deploy-example-app:android` or
`deploy-example-app:ios`; the label is removed after the run, so re-applying it
deploys again. Unit tests and lint must pass first. Deploys are skipped, not
failed, until the required secrets exist: a push or release with missing secrets
ends green with a notice naming them, while a manual or label deploy fails
loudly.

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
- `release-notes.sh`: store release notes for one platform. A header block (app version and build
  number, the Flutter SDK and that platform's native SDK with their refs, commit, source, build time),
  then the CI run line, then the GitHub release body on `release` events only. There is no commit
  subject fallback. Over the cap (4000 characters for TestFlight, 500 for Play) the release body is cut
  first, then the CI run line; header lines are never cut, and any cut ends with `…[truncated]`.
- `gradle-retry.sh`: wraps the flutter build so a JitPack timeout or 404 while
  resolving the Android SDK retries with `--refresh-dependencies`; any other
  build failure exits immediately.
- `scripts/sdk-ref.sh` (repo root): writes `example/build-info.json` with the
  Flutter, iOS and Android SDK refs (plain version, or `branch@sha`), commit, branch, source label and
  event that the builds embed via `--dart-define-from-file`. The app shows them in a Build info sheet
  opened from the info button on the Profile tab. In CI an empty commit, branch or source label fails
  the stamp instead of falling back to git or `GITHUB_SHA`.
- `source-label.sh`: the source shown in notes and Slack: the release tag, the pull request head
  branch with its number, or the branch name. It refuses a pull request without a head ref in CI.
- `check-secrets.sh`: the preflight. Prints only the names of missing secrets; push and release skip
  with a notice, manual and label deploys fail.
- `slack-payload.sh`: builds the Slack message as JSON so a multiline value cannot break the request.
- `ios-marketing-version.sh`: the numeric part of the SDK version for `CFBundleShortVersionString`
  (`0.3.2-alpha.1` becomes `0.3.2`); fails on a version Apple would reject.
- `lint-action-shell.py`: extracts the `run:` blocks from the composite actions and runs shellcheck on
  them, since actionlint does not read `action.yml`.
- `tests/`: offline suites for each of the above, plus `test-workflow-guards.py` and its self-test,
  which check the workflows for what actionlint cannot.

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
- `SLACK_WEBHOOK_URL`: incoming webhook for the publish channel. Optional: when unset the Slack steps
  skip with a notice, and a Slack problem never fails a deploy.

Repository variables:

- `PLAY_RELEASE_STATUS=draft` until the first Play release is rolled out

The deploy jobs run in GitHub environments — `android-internal-track` for
Play, `testflight` for App Store Connect (same names as the native test
apps) — for the deploy URL and history. Store secrets must be repository
secrets, not environment secrets; the preflight jobs declare no environment
and cannot see environment secrets, so they would skip every deploy forever.
Deploys are skipped, not failed, until the required secrets exist: pushes to
`master`/`rel/**` and releases skip green with a `::notice::` naming the
missing secrets, while `workflow_dispatch` and `deploy-example-app` label
deploys fail loudly. `workflow_dispatch` with `check_credentials` verifies
both setups end to end without uploading: keystore + Play edit round-trip on
Android, ASC key + match repo read on iOS.

A push to `rel/**` followed by a published release from the same commit
deploys twice with different build numbers; both deploys are valid (the
second gets the next build number via the pre-upload recheck).

## Public build logs

This repo is public, so anyone can read the Actions logs. The scripts never echo
secrets or run with `set -x`, and Slack only gets links that need a Play tester
or App Store Connect login to open. Do not add steps that print environment
variables, upload signed artifacts, or post public TestFlight links.
