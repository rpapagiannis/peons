# Repository Guidelines

## Project Structure & Module Organization

Peons is a native Swift desktop companion for Apple Silicon Macs running macOS 14+.

- `Sources/`: `App.swift` owns native UI and preferences; `PetModel.swift` handles physics and monitors; `Characters.swift` defines characters; rendering and audio have dedicated files.
- `Tests/`: Swift regression executables and Python release tests.
- `assets/`: sprite sheets, audio originals, normalized recordings, manifests, and attribution.
- `scripts/` and `distribution/`: audio preparation, packaging, release automation, and Homebrew configuration.
- `research/` records behavior rationale and asset provenance; `docs/` holds demo GIFs. Generated `build/` and `dist/` are ignored by Git.

## Build, Test, and Development Commands

Install Apple's Command Line Tools and ensure `python3` is available. Run from the repository root:

- `./build.sh`: compile and ad-hoc sign `build/Peons.app`.
- `./test.sh`: run all Swift and Python regression suites.
- `./test.sh --audio-playback`: additionally exercise real audio playback at zero volume; requires audio output.
- `open build/Peons.app`: launch the development build; quit any running copy first.
- `./scripts/package_release.sh`: package the built app into a DMG and SHA-256 sidecar in `dist/`.
- `swift scripts/prepare_audio.swift`: regenerate normalized audio, then rebuild.

## Coding Style & Naming Conventions

Use four-space indentation, `UpperCamelCase` for Swift types, and `lowerCamelCase` for members. Match surrounding formatting and keep unrelated formatting changes out of patches. Compile in Swift 5 mode as configured by the scripts. No formatter or linter is configured.

## Testing Guidelines

Swift tests use standalone `@main` executables with assertions; release tests use Python `unittest`. Name Swift suites `Tests/<Area>Tests.swift` and register new suites in `test.sh`. Python test methods use `test_` names.

Add regression checks for changed behavior. No numeric coverage threshold is configured. For interaction changes, manually exercise both characters, keyboard control, roaming, dragging/throwing, portals, sound, and monitor transitions as applicable. CI runs the build and full suite.

## Commit & Pull Request Guidelines

Use concise, imperative commit subjects, following history: `Add Warcraft Peon as a second character` or `Fix controls sizing and reduce sprite hit-testing overhead`. Keep changes focused.

PRs should explain the problem, resulting behavior, and validation; link related issues and include screenshots or GIFs for visual changes. Record user-facing changes under `## Unreleased` in `CHANGELOG.md`. Successful `main` CI automatically releases and increments the build number; see `distribution/README.md`.

## Compatibility & Assets

Preserve the legacy bundle identifier and preference migrations. Keep asset manifests and `assets/ATTRIBUTION.md` current. Preview packages are ad-hoc signed; packaging does not notarize them.
