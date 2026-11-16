# Staged shared CI changes (MAGE-1729, part of MAGE-1725)

The push token for this branch can't write workflow files, so this directory holds the intended end state of every new or changed `.github/` file. Before merge, someone with workflow permissions copies each file under `ci-staging/github/` to the same path under `.github/`, deletes every path listed in `ci-staging/DELETE`, and removes `ci-staging/`. After that, klaviyo-flutter-sdk calls the shared CI in klaviyo-react-native-sdk rather than keeping its own copies. `notify-slack` comes from `.github/shared/notify-slack` and the local action is deleted. `pr-target-check.yml`, `stale.yml` and a new `promotion-check.yml` become stubs over the shared actions. The Linear sync in `release.yml` and the label cleanup in `publish-example.yml` use `linear-release-sync` and `remove-deploy-label`. `publish-release.yml` calls `release-preflight.yml`, then runs its own `dart pub publish --dry-run` and publish jobs. `rel-branch.yml` calls `rel-branch-core.yml` and keeps its `pin` job. Refs point at `@ecm/mage-1726/shared-ci` until klaviyo-react-native-sdk#501 merges, then flip to `@master`.

Apply locally:

```bash
cp -R ci-staging/github/. .github/
xargs git rm -q < ci-staging/DELETE
git rm -rq ci-staging
```
