# Release Pipeline

`.github/workflows/release.yml` builds an **unsigned IPA** and attaches it to a GitHub
Release whenever an authorized maintainer pushes a release tag.

```
push tag v1.1
  └─ authorize (ubuntu)          ← tag format + actor allowlist + branch reachability
  └─ build (macos-26)            ← `release` environment: required reviewers
       ├─ checkout --recurse-submodules   (Vendor/ emulator cores)
       ├─ xcodebuild archive CODE_SIGNING_ALLOWED=NO
       ├─ zip Payload/romm.app → romm-v1.1.ipa
       └─ gh release create v1.1 romm-v1.1.ipa
```

## Triggering a release

```sh
git tag v1.1
git push origin v1.1
```

Accepted tags: `v<major>.<minor>[.<patch>][-prerelease]` — `v1.1`, `v1.0.0`,
`v1.0.0-beta.13`. A tag with a prerelease suffix is published as a GitHub pre-release.

The tag drives `MARKETING_VERSION` for the build, so `v1.1` produces an app reporting
version `1.1`. Any prerelease suffix is dropped for the bundle version, because
`CFBundleShortVersionString` only accepts one to three dot-separated integers —
`v1.0.0-beta.13` builds as `1.0.0`.

`CURRENT_PROJECT_VERSION` is deliberately left alone so this workflow can never collide
with the build numbers that `fastlane deploy_testflight` increments.

To rebuild an existing tag, run the workflow manually from the Actions tab
(**Release → Run workflow**) and enter the tag. It replaces the IPA on the existing
release rather than creating a second one.

## One-time repository setup

Both gates below are independent — the workflow runs with either one alone, but they
are meant to be used together.

### 1. The `release` environment (approval gate)

**Settings → Environments → New environment → `release`**

- **Required reviewers**: add yourself (and any co-maintainers). Every tag push then
  waits for a human to approve in the Actions tab before anything is built or published.
- **Deployment branches and tags** → *Selected branches and tags* → add a tag rule
  `v*`. This stops the environment being reachable from any other ref.

  If you also want the manual **Run workflow** rebuild path to work, add a branch rule
  for `main` alongside it. `workflow_dispatch` runs from a branch ref, not the tag, so a
  tags-only rule blocks it — the `authorize` job still validates the tag you type in.

If you skip this, GitHub creates the environment unprotected on the first run and
releases publish without approval.

### 2. Repository variables (authorization gate)

**Settings → Secrets and variables → Actions → Variables**

| Variable | Default | Purpose |
|---|---|---|
| `RELEASE_AUTHORS` | repository owner | Comma/newline separated GitHub logins allowed to publish. Case-insensitive. |
| `RELEASE_BRANCHES` | repository default branch | Comma/newline separated branches a release tag must be reachable from. |

`RELEASE_BRANCHES` is what stops a tag pushed onto an arbitrary unreviewed commit from
being released — the tagged commit has to already be on `main`. Widen it only if you
start cutting releases from maintenance branches.

No secrets are required. The workflow only uses the automatic `GITHUB_TOKEN`, scoped to
`contents: write` on the build job alone.

## Installing the IPA

The published IPA is unsigned, so iOS will not install it directly. Users re-sign it with
their own Apple ID via [AltStore](https://altstore.io), [SideStore](https://sidestore.io),
or [Sideloadly](https://sideloadly.io). The release notes carry a SHA-256 checksum.

TestFlight remains the signed distribution channel and is unchanged — it is still driven
manually by `bundle exec fastlane deploy_testflight`.

## Repository changes this pipeline depends on

Two things had to change for the project to build from a clean clone. Both matter to
local development too, not just CI:

1. **`romm/romm.xcodeproj/xcshareddata/xcschemes/romm.xcscheme`** — the project had no
   shared scheme, only per-user ones under the gitignored `xcuserdata/`. `xcodebuild
   -scheme romm` fails on a fresh clone without it. The scheme keeps
   `buildImplicitDependencies = "YES"`, which is required: the app links
   `GPGXDeltaCore`, `NESDeltaCore`, `N64DeltaCore`, `MelonDSDeltaCore` and
   `GBCDeltaCore` without declaring them as target dependencies, so Xcode has to infer
   them.

2. **`mft.xcframework` path** — it pointed at `../../mft 2025-08-24 21-54-12/mft.xcframework`,
   a path outside the repository that only existed on one machine. It now points at
   `../mft.xcframework`, the copy committed at the repository root.

## Runner and Xcode

The build pins `runs-on: macos-26`. The project needs the iOS 18.6 SDK or newer
(`IPHONEOS_DEPLOYMENT_TARGET = 18.6`) and Xcode 16.3+ for its project format
(`objectVersion = 77`).

By default the workflow selects the newest Xcode installed on the image. Pin a specific
one by setting the `XCODE_VERSION` env in the `build` job, e.g. `XCODE_VERSION: '26.0'`
for `/Applications/Xcode_26.0.app`; the build fails with the list of installed versions
if that one is absent.

## Troubleshooting

**Build fails on the Delta cores.** Confirm the submodules resolved — the workflow uses
`submodules: recursive`, and the cores reference `Vendor/DeltaCore` in turn. A shallow
or partial submodule checkout produces missing-framework link errors.

**"is not reachable from any release branch".** The tagged commit is not on `main`.
Merge it first, or add the branch to `RELEASE_BRANCHES`.

**The job is stuck on "Waiting for review".** That is the `release` environment doing its
job. Approve it in the Actions tab.

**Full `xcodebuild` output.** On failure the workflow uploads the unfiltered log as the
`xcodebuild-log-<tag>` artifact, retained for 14 days.
