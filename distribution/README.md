# Sharing Peons

## Current compatibility

The app is native Swift/AppKit/SwiftUI and currently builds only for Apple Silicon (`arm64`) on macOS 14 Sonoma or later. Recipients do not need Xcode, Swift, Python, or Homebrew to run a downloaded app. Intel Macs need a separately built and tested `x86_64` version or a universal binary. Windows and Linux need a port of the native windows, rendering, input, and audio integration; changing the installer cannot add support.

## Recommended distribution

Offer one versioned DMG through a download page or GitHub Releases, with the app and an Applications shortcut. Users drag the app into Applications and launch it. A Homebrew cask can download and install the same DMG. A `.pkg` installer is unnecessary for this self-contained app, which has no services or system components to install.

Maintain the cask in an owner-controlled Homebrew tap, such as a GitHub repository named `homebrew-peons`. This does not require admission to Homebrew's central cask repository. After it is configured and published, the install command would be:

```sh
# Example only: replace GITHUB_OWNER with the actual published tap owner.
brew install --cask GITHUB_OWNER/peons/peons
```

The tap holds a small installation recipe with the version, exact download URL, SHA-256 checksum, and architecture/OS requirements. Homebrew users can upgrade with `brew upgrade --cask peons` once the recipe is updated for a release. Direct-download users download the next DMG and replace the app; an in-app updater is not implemented.

See the official [tap guide](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) and [cask format](https://docs.brew.sh/Cask-Cookbook). `peons.rb.in` is a template, not a published or installable cask. Fill every `@...@` field from the final release and save it as `Casks/peons.rb` in the chosen tap. The template intentionally preserves user preferences during uninstall; the legacy bundle identifier is shared with earlier local prototypes.

## Build a local preview DMG

```sh
./build.sh
./test.sh
./scripts/package_release.sh
```

The packaging helper preserves the built app's signature and writes a versioned DMG and SHA-256 sidecar to `dist/`. The current preview is 4.2.2 (build 9). Keep the preceding installer until the replacement passes signature, mounted-content, and checksum checks, then remove obsolete releases. It does not upload, install, sign with a Developer ID, or notarize anything. Run it with `--help` for input/output options. The current development app is ad-hoc signed, so packaging it does not make it a notarized public release. macOS may block a downloaded copy under its normal security checks.

## Prepare a public release

1. Establish redistribution permission for the bundled artwork and recordings, or use assets with suitable permissions. `assets/ATTRIBUTION.md` records Pocket Mortys game sprites and Rick and Morty recordings; it does not establish a redistribution license for the underlying material. Attribution and an upstream fan-pack license do not document that missing permission.
2. Choose the owner/repository for release downloads and the Homebrew tap. Nothing has been published by the local packaging step.
3. Configure an Apple Developer ID Application certificate and notarization credentials. Apple's [Developer ID distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) is the supported route for distributing this native app outside the App Store. The current `build.sh` uses ad-hoc signing instead.
4. Build and test the release; sign the app with Developer ID, the hardened runtime, and a secure timestamp. Submit for notarization and staple its ticket. Create the DMG from that finished app, then sign/notarize/staple the distribution image as appropriate using Apple's [notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
5. Compute the final DMG checksum only after all signing/stapling operations. If those changed a packaged DMG, regenerate its checksum sidecar. Test the actual browser-downloaded artifact on a clean supported Mac, with Gatekeeper enabled, including install, first launch, audio, quit, and replacement by a newer version.
6. Publish the immutable versioned DMG and its matching checksum, then update the tap with that exact URL/checksum/version. Audit and install the configured cask against the hosted artifact before advertising the command.

The Apple Developer Program currently lists 99 USD per membership year, with regional pricing and some fee waivers: [Apple enrollment](https://developer.apple.com/programs/enroll/). No membership has been purchased, certificate requested, or credentials inspected by this preparation work.
