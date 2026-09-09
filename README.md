# Peons

[![Download for macOS](https://img.shields.io/github/v/release/rpapagiannis/peons?style=for-the-badge&logo=apple&logoColor=white&label=Download%20for%20macOS&color=1f6feb)](https://github.com/rpapagiannis/peons/releases/latest)
[![Homebrew](https://img.shields.io/badge/Homebrew-brew%20install%20----cask%20rpapagiannis%2Fpeons%2Fpeons-2b2b2b?style=for-the-badge&logo=homebrew&logoColor=white)](#homebrew)
[![CI](https://github.com/rpapagiannis/peons/actions/workflows/ci.yml/badge.svg)](https://github.com/rpapagiannis/peons/actions/workflows/ci.yml)

![Rat Suit Rick walking along the floor, jumping, facing the viewer, and being thrown across the desktop](docs/demo.gif)

![Warcraft Peon walking, jumping, facing the viewer, and being thrown across the desktop](docs/peon-demo.gif)

A native macOS desktop companion featuring **Rat Suit Rick** and **Warcraft Peon**. They walk, jump, roam, and can be picked up and thrown across every connected monitor. No accounts, no network calls, and no special permissions.

## Install

Requires an Apple Silicon Mac running macOS 14 or later.

### Download

1. Download the latest `Peons-…-arm64-preview.dmg` from the [Releases page](https://github.com/rpapagiannis/peons/releases/latest).
2. Open the disk image and drag **Peons.app** onto the **Applications** shortcut.
3. Launch Peons from Applications. Rick lands on the desktop floor, a pickle icon appears in the menu bar, and the controls window opens on the very first launch.

**First launch.** This preview is ad-hoc signed rather than notarized, so macOS blocks the first launch with a warning that it cannot verify the app, or on some systems that the app is damaged. Open **System Settings → Privacy & Security**, scroll to the Security section, click **Open Anyway** next to Peons, and confirm. On macOS 14, Control-clicking the app and choosing **Open** also works. If macOS insists the app is damaged, clear the download's quarantine flag and launch again:

```sh
xattr -d com.apple.quarantine /Applications/Peons.app
```

This is a one-time step per version and goes away once releases are Developer ID signed and notarized.

### Homebrew

```sh
brew install --cask rpapagiannis/peons/peons
```

The cask in [rpapagiannis/homebrew-peons](https://github.com/rpapagiannis/homebrew-peons) installs the same disk image, so the same first-launch approval applies. Homebrew 6 has no option to skip quarantine, and because an ad-hoc signature changes with every build, Homebrew cannot carry the approval over to upgrades either, so each new version asks once. Homebrew 6 trusts only this cask when it is installed by its fully qualified name, so no separate `brew tap` or `brew trust` step is needed. Update later with `brew upgrade --cask peons`.

### Verify a download

Every release ships a `.sha256` file next to the disk image. From the folder holding both:

```sh
shasum -a 256 -c Peons-*.dmg.sha256
```

## Using Peons

Choose **Rat Suit Rick** or **Warcraft Peon** in the controls window or the menu's **Character** submenu. The selected character is remembered across launches. Tiny is the only size (135.68 × 180.2 screen points for the transparent canvas); each character keeps its own proportions. Unknown or retired character choices fall back to Rick, and old size choices migrate to Tiny.

Open **Peons.app** in your Applications folder. Click your character to play; click another app or press Escape to return to roaming. The pickle icon in the menu bar opens the menu. The controls window shows both character choices, an animated preview, and sound controls; it can be resized vertically and scrolls on shorter displays. Switching preserves position, movement, jumps, throws, naps, and portal travel, while replacing the previous recording with the selected character's next line.

Warcraft Peon uses the original Warcraft II pixel sprites and all 17 English Warcraft III recordings from Peon Ping. Rick retains his 17 recordings. Each character advances through its own complete voice cycle and resumes where it left off when selected again. Both packs use the same volume, mute, and occasional-chatter settings.

In free roam, Rick mixes walking and resting with occasional high jumps and rarer portal trips to a different spot, including other connected monitors. About one in three jumps gets a second boost near the top, and every autonomous jump holds full left or right movement at the selected speed until landing. He waits between actions and lets throws and landings finish first. Hover over him to keep him easy to catch; autonomous actions pause while you interact with him, open his menu, or put him down for a nap. Voices continue to follow the existing occasional-chatter setting.

Each portal trip opens with the recorded Rick and Morty portal sound, including P, the menu, summoning, and free roam. It shares the voices' mute and volume controls and replaces any current recording. Portal effects do not advance the voice-line cycle or show a speech bubble. Turning off occasional chatter keeps portal effects enabled; muting, hiding Rick, or putting him down for a nap silences both voices and effects.

| Control | Action |
| --- | --- |
| Click your character | Take keyboard control |
| A / D or Left / Right | Walk |
| S or Down | Face the viewer |
| Shift + movement | Move faster |
| W / Up / Space or double-click | Jump; press again in midair for a second jump |
| Drag and release | Pick up and throw with momentum |
| P | Portal to another spot, including another monitor |
| E | Play the next voice line |
| M | Mute or unmute all sound |
| Escape | Release keyboard control and roam |
| Right-click your character | Character, controls, speed, nap, sound, hide, summon, quit |
| C or H while controlling | Open character controls |

All connected monitors form one desktop. Rick walks, jumps, or flies across internal monitor seams without bouncing or wrapping. Wrapping happens only beyond the far left and right edges of the combined desktop. Ground travel follows each monitor's usable bottom edge, stepping to the receiving floor when the monitors have different vertical offsets. The screen bottom is the only platform; application windows and boxes are not detected. Disconnecting a monitor brings Rick back onto a remaining screen.

Gravity brings unsupported Rick down. A normal jump rises about 180–380 screen points depending on the current display. Throws bounce, lose energy, and settle. Keyboard input stays local to the focused pet panel. Speed, volume, mute, and occasional-chatter preferences are remembered.

This is a local, ad-hoc-signed Apple Silicon app for macOS 14+. The app makes no network calls and requires no Accessibility, Input Monitoring, or screen recording permission. It does not install a login item. System security surfaces and some exclusive fullscreen apps can cover floating windows.

## Build from source

Requires Apple's Command Line Tools:

```sh
./build.sh
./test.sh
open "build/Peons.app"
```

For an additional real-player check on a Mac with audio output, run `./test.sh --audio-playback`. Playback uses zero volume. The default suite validates the audio files and controller behavior without requiring an output device.

Builds produce a fresh `build/Peons.app` containing both character sheets, 34 voice recordings, and the portal effect, with a Rick app icon generated from his atlas. Only manifest-referenced, normalized audio is bundled. Build and test compiler caches are temporary and removed when each command exits. Retired characters, rolling animations, prototype renderers, and their assets have been removed from the source tree. Rebuilding does not install the bundle into Applications: replace the installed copy and restart it to use an updated build.

To package locally, run `./scripts/package_release.sh` after building; it writes `dist/Peons-<version>-<build>-arm64-preview.dmg` and its SHA-256 checksum. After a merge or push to `main` passes CI, GitHub Actions increments the build number, moves the unreleased changelog entries into that release, and builds and tests the versioned app. It then commits the release metadata, pushes the matching tag, publishes the DMG and checksum, and updates the Homebrew cask. Add changes under `## Unreleased` in `CHANGELOG.md`; edit the app version in `build.sh` only when a new major, minor, or patch version is wanted. Manual tag releases, dry runs, and cask repair remain available. See [distribution/README.md](distribution/README.md). Preview builds are ad-hoc signed; Developer ID signing and notarization are still to do, and the redistribution basis for the bundled artwork and recordings is recorded in [assets/ATTRIBUTION.md](assets/ATTRIBUTION.md).

`Sources/Characters.swift` defines the supported catalog and voice pack. `SoundPlayer.swift` provides the single audio channel shared by dialogue and effects. `PetModel.swift` owns shared physics, the fixed desktop size, monitor geometry, and accepted portal openings. `SpriteRenderer.swift` draws the artwork and effects. `App.swift` provides the native panel, controls, and migration of old preferences.

Development exports:

```sh
"build/Peons.app/Contents/MacOS/Peons" --render /absolute/preview.png
"build/Peons.app/Contents/MacOS/Peons" --export-demo /absolute/preview.gif
"build/Peons.app/Contents/MacOS/Peons" --character peon --render /absolute/peon.png
"build/Peons.app/Contents/MacOS/Peons" --character peon --export-demo /absolute/peon.gif
```

`--diagnostics /absolute/path.json` writes only this app's internal state and display geometry. It is disabled in normal launches. The legacy bundle identifier `local.rafail.pickle-rick-pet` and migration of saved character/size choices are retained for compatibility with earlier installations.

The Rick voice selection and comparison are documented in `research/VOICE_PACKS.md`; the portal source and playback behavior are in `research/PORTAL_SOUND.md`. To reproduce all balanced sound files from the pinned original recordings, run `swift scripts/prepare_audio.swift`, then rebuild. This preparation step uses macOS audio decoding services and does not play audio.

Artwork and sound provenance, including the pinned Peon Ping pack and Warcraft sprite coordinates, are in `assets/ATTRIBUTION.md`. This is an unofficial personal project; the character artwork belongs to its respective rights holders. Both original sheets are bundled unmodified and existing poses are selected at runtime. Recorded voice clips play locally with matching speech bubbles.

## Project layout

- `Sources/` and `Tests/`: the character catalog, shared desktop app, and regression coverage.
- `assets/`: both sprite sheets, 34 normalized voices, the normalized portal effect, original recordings, and attribution.
- `research/`: movement rationale and the pinned sound selection/provenance needed to reproduce the assets.
- `scripts/` and `distribution/`: audio preparation, DMG packaging, the Homebrew cask template, and the release process notes.
- `CHANGELOG.md`: what changed in each release; the release workflow copies the matching section into the GitHub release notes.
- `docs/`: the demo animation shown above, exported with `--export-demo`.
- `.github/workflows/`: CI for pushes to `main` and pull requests; successful `main` builds call the reusable release workflow to version, publish, and update Homebrew. Manual tags and dry runs use the same release workflow.
- `dist/`: the latest locally packaged preview DMG and its checksum. Not tracked in git; release downloads live on GitHub Releases.

Generated app bundles are disposable; rebuild them with `./build.sh`. Old renamed app copies, obsolete installers, and prototype snapshots are not kept in this directory.
