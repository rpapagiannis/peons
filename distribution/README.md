# Sharing Peons

## Current compatibility

The app is native Swift/AppKit/SwiftUI and currently builds only for Apple Silicon (`arm64`) on macOS 14 Sonoma or later. Recipients do not need Xcode, Swift, Python, or Homebrew to run a downloaded app. Intel Macs need a separately built and tested `x86_64` version or a universal binary. Windows and Linux need a port of the native windows, rendering, input, and audio integration; changing the installer cannot add support.

## Recommended distribution

Offer one versioned DMG through a download page or GitHub Releases, with the app and an Applications shortcut. Users drag the app into Applications and launch it. A Homebrew cask can download and install the same DMG. A `.pkg` installer is unnecessary for this self-contained app, which has no services or system components to install.

The cask lives in the owner-controlled tap [rpapagiannis/homebrew-peons](https://github.com/rpapagiannis/homebrew-peons) as `Casks/peons.rb`. This does not require admission to Homebrew's central cask repository. The install command is:

```sh
brew install --cask rpapagiannis/peons/peons
```

On Homebrew 6, installing by the fully qualified name trusts only this cask, so users need no separate `brew tap` or `brew trust` step. To validate the cask locally before pushing, note that `brew tap` refuses an untrusted local tap during its load check; instead clone the tap repository into `$(brew --repository)/Library/Taps/rpapagiannis/homebrew-peons`, run `brew trust rpapagiannis/peons`, then `brew style --cask rpapagiannis/peons/peons` and `brew audit --cask --strict rpapagiannis/peons/peons`, and finish with `brew untap rpapagiannis/peons` and `brew untrust rpapagiannis/peons`.

Homebrew 6.0.14 removed the `--no-quarantine` option, so there is no install-time way around Gatekeeper. Since 6.0.10 Homebrew carries a user's Gatekeeper approval forward across cask upgrades, but only when the new app satisfies the old app's designated requirement. An ad-hoc signature's requirement is a per-build `cdhash`, so it never matches and every version asks once. A stable signing identity, at minimum a self-signed certificate and ideally Developer ID, is what makes later upgrades dialog-free through Homebrew; notarization is what removes the first dialog for everyone.

The tap holds a small installation recipe with the version, exact download URL, SHA-256 checksum, and architecture/OS requirements. Homebrew users can upgrade with `brew upgrade --cask peons` once the recipe is updated for a release. Direct-download users download the next DMG and replace the app; an in-app updater is not implemented.

See the official [tap guide](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) and [cask format](https://docs.brew.sh/Cask-Cookbook). `peons.rb.in` here is the reference template for that cask; the live copy in the tap is what Homebrew installs. Its `version` is `<version>,<build>` and the download URL is derived from the matching `v<version>-<build>` release tag. `uninstall` only quits the app so preferences survive; `brew uninstall --zap` removes the preference file as well. The bundle identifier is the legacy one shared with earlier local prototypes.

## Automated releases

After a push or merge to `main` passes the build and test job, `.github/workflows/ci.yml` calls the reusable `.github/workflows/release.yml` in `auto` mode. Pull requests only build and test. Automatic releases require `HOMEBREW_TAP_TOKEN`, so a missing token fails visibly before creating release metadata.

The release job checks out the exact commit that passed CI. `scripts/release.py` increments `CFBundleVersion` to one above both the current build and all existing release-tag build numbers, retaining `CFBundleShortVersionString`. It moves `## Unreleased` entries into `## <version> (build <build>)` while leaving an empty Unreleased section for the next change. The versioned app is then built, tested, and packaged on an Apple Silicon runner. Only after those steps pass does the job atomically push the release commit to `main` and its `v<version>-<build>` tag, publish the DMG and `.sha256` sidecar, and update the Homebrew cask. The source commit is recorded in the release commit's `Peons-Release-Source` trailer.

Release jobs share one concurrency group with `queue: max` and cancellation disabled. Up to 100 pending jobs are retained, so an older CI run finishing later or a manual dry run cannot replace a pending release. If `main` advances before preparation or while the app is building, the older run skips publication and the newer successful run includes both changes. A non-fast-forward push is rejected atomically, so a racing merge cannot be overwritten or leave an orphan tag. Rerunning a failed job after the refs were pushed reuses its release commit and tag; if the release already exists, its assets are preserved and the job finishes the cask update. The cask update refuses to downgrade an already newer version. Rerun failed jobs on the original CI run to recover a packaging, publishing, or cask failure.

The release commit and tag use the repository's `GITHUB_TOKEN`. [GitHub does not start another push-triggered workflow for those writes](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow), so the same job continues directly to publication without a recursive release loop. The release job explicitly requests Contents: write; other CI jobs use Contents: read. `main` must permit this bot's fast-forward release commits. If branch rules later require all updates through PRs, adapt the release strategy or explicitly allow the release bot; the workflow does not bypass those rules.

Manually pushing a tag starting with `v` also runs the release workflow. It refuses tags that do not match the version and build in `build.sh`, then runs `build.sh`, `test.sh`, and `scripts/package_release.sh`, and publishes the DMG plus its `.sha256` sidecar. Release notes include install steps, the checksum, and the matching section of `CHANGELOG.md`. If a release for that tag already exists, its assets are never replaced by a CI build with a different checksum; the job reads the published `.sha256` and brings the cask up to date. The cask's download URL is rewritten from the real asset name, so the `-preview` suffix disappearing after Developer ID signing needs no manual edit.

The workflow can also be run by hand from the Actions tab in two modes. `dry-run` builds, tests, and packages on the runner and uploads the DMG as a workflow artifact without tagging or publishing anything; it passed on 2026-09-08. `sync-cask`, given a release tag, rewrites the cask from that release's `.sha256` asset, or verifies push access when the cask already matches. Use it once right after setting the token to prove the automation, or to repair the cask after a failed update. GitHub-hosted macOS runners occasionally fail `hdiutil create` with a resource-busy error, which `package_release.sh` retries.

For routine releases, merge the PR and let CI finish. Put user-facing changes under `## Unreleased`; change `CFBundleShortVersionString` in `build.sh` when a new major, minor, or patch version is appropriate. The build number advances automatically. For an explicitly managed tag release, set the version/build and matching changelog heading before pushing `v<version>-<build>`. Avoid racing a manual tag with an automatic release of the same change.

To have the workflow bump the cask automatically, create a fine-grained personal access token at https://github.com/settings/personal-access-tokens/new with resource owner `rpapagiannis`, repository access limited to `homebrew-peons`, the single repository permission Contents: Read and write, and the longest expiration you accept. Store it with `gh secret set HOMEBREW_TAP_TOKEN --repo rpapagiannis/peons`, pasting the token at the prompt so it never lands in shell history. Then run the workflow in `sync-cask` mode for the current tag: `gh workflow run release.yml --repo rpapagiannis/peons -f mode=sync-cask -f tag=v4.2.2-9`. When the token expires, the tap step fails visibly on the next release; create a new token and set the secret again. Without the secret, copy the new version and the SHA-256 from the release's sidecar into `Casks/peons.rb` by hand.

`.github/workflows/ci.yml` builds and runs the full test suite on every push to `main` and every pull request, including temporary-repository tests of release retries, concurrent merges, atomic push failures, version allocation, and cask downgrade prevention.

## Build a local preview DMG

```sh
./build.sh
./test.sh
./scripts/package_release.sh
```

The packaging helper preserves the built app's signature and writes a versioned DMG and SHA-256 sidecar to `dist/`. The current preview is 4.2.2 (build 9). Keep the preceding installer until the replacement passes signature, mounted-content, and checksum checks, then remove obsolete releases. It does not upload, install, sign with a Developer ID, or notarize anything. Run it with `--help` for input/output options. The current development app is ad-hoc signed, so packaging it does not make it a notarized public release. macOS may block a downloaded copy under its normal security checks.

## Prepare a public release

1. Establish redistribution permission for the bundled artwork and recordings, or use assets with suitable permissions. `assets/ATTRIBUTION.md` records Pocket Mortys game sprites and Rick and Morty recordings; it does not establish a redistribution license for the underlying material. Attribution and an upstream fan-pack license do not document that missing permission.
2. Release downloads live on the GitHub Releases page of `rpapagiannis/peons`, and the Homebrew tap is `rpapagiannis/homebrew-peons`. The local packaging step itself publishes nothing.
3. Configure an Apple Developer ID Application certificate and notarization credentials. Apple's [Developer ID distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) is the supported route for distributing this native app outside the App Store. The current `build.sh` uses ad-hoc signing instead.
4. Build and test the release; sign the app with Developer ID, the hardened runtime, and a secure timestamp. Submit for notarization and staple its ticket. Create the DMG from that finished app, then sign/notarize/staple the distribution image as appropriate using Apple's [notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
5. Compute the final DMG checksum only after all signing/stapling operations. If those changed a packaged DMG, regenerate its checksum sidecar. Test the actual browser-downloaded artifact on a clean supported Mac, with Gatekeeper enabled, including install, first launch, audio, quit, and replacement by a newer version.
6. Publish the immutable versioned DMG and its matching checksum, then update the tap with that exact URL/checksum/version. Audit and install the configured cask against the hosted artifact before advertising the command.

The Apple Developer Program currently lists 99 USD per membership year, with regional pricing and some fee waivers: [Apple enrollment](https://developer.apple.com/programs/enroll/). No membership has been purchased, certificate requested, or credentials inspected by this preparation work.
