# .github Guidelines

For agents and humans editing workflows and actions here. `CLAUDE.md` in this directory points to this file.

## Slack

- Use only `.github/actions/notify-slack` for Slack. It wraps slackapi/slack-github-action, so don't call slackapi or curl directly.
- `token: ${{ secrets.SLACK_BOT_TOKEN }}`. An empty token skips, so no presence checks.
- One message per release or deploy, updated through `ts` (job output or dispatch input). Failure details go in a `thread_ts` reply.
- Each workflow sets `SLACK_USERNAME` and `SLACK_ICON_EMOJI` in its top-level `env:` ("Flutter SDK" for the release workflows, "Flutter Example App" for `publish-example.yml`, both `:merlin-orb-flutter:`).
- `continue-on-error: true` on Slack notify steps and Slack-action checkout steps.
- Report a cancelled deploy job only on timeout: the `Classify cancellation` step in `publish-example.yml`. `publish-release.yml` updates its pending message to stopped whenever its `publish` job is cancelled after posting it.
- `publish-example.yml` keeps one live message: `announce` posts `pending` (title "Flutter Example App deploying" plus the version) once a deploy will run, `progress` edits it when tests and lint pass, `report` makes the final edit (deployed, failed, blocked with the failed job named, credential check result, stopped or timed out), and each deploy job replies in its thread. When `slack_thread_ts` is set, `announce` posts its message as a reply in that release thread. There is no separate `blocked` post.
- `release.yml` has its own `announce` job that posts the `pending` message only when it was not given `slack_ts` (tag pushed from the UI). It passes that message on to `publish-example.yml` as `slack_thread_ts` like a dispatched one.
- `publish-release.yml` passes `slack_ts` to `release.yml`, which updates that message and passes it on to `publish-example.yml` as `slack_thread_ts`. Jobs that run before or without a full checkout sparse-checkout `.github/actions` into `_slack/`.
- `notify-slack` stays byte-identical in all 7 repos: klaviyo-android-sdk, klaviyo-android-test-app, klaviyo-swift-sdk, klaviyo-ios-test-app, klaviyo-react-native-sdk, klaviyo-expo-plugin, klaviyo-flutter-sdk.

## Workflow conventions

- Pin actions by full SHA with a `# vX` comment in new or edited workflows.
- Check out with `persist-credentials: false`.
- `publish-example.yml` skips docs, CI and config-only changes via `paths-ignore`. Add new CI-only paths there.
- `publish-release.yml` uses a `concurrency` group with `cancel-in-progress: false`.
