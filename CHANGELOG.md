# Changelog

After CI passes on `main`, the release workflow advances the build number and moves Unreleased entries into `## <version> (build <build>)`, then copies that section into the GitHub release notes.

## Unreleased

## 4.2.2 (build 13)

## 4.2.2 (build 12)

- Give about one in three free-roam jumps a second boost near the top, and hold full directional movement at the selected speed throughout every autonomous jump.

## 4.2.2 (build 11)

- Play the recorded Rick and Morty portal effect once for each manual, summoned, or autonomous portal opening. Refused requests stay silent and portal actions preserve the voice-line cycle.
- Share one audio player, mute/volume settings, lifecycle cleanup, and offline level balancing between voices and effects. Sound controls now describe both, and idle chatter waits for the portal recording to finish.
- Bundle the manifest-selected normalized portal recording with source attribution and checksums; add portal sound regression coverage.

## 4.2.2 (build 10)

- Rick now makes occasional high jumps and opens portals to clearly separated floor destinations while roaming freely, including across monitors.
- Autonomous actions wait for throws and landings, pause for hovering and interaction, and leave room to catch Rick before resuming. Existing voice and chatter preferences still apply.
- Deterministic regression coverage for free-roam behavior, interruption, cooldowns, and desktop geometry.
- Successful merges to `main` now create a versioned release and update the Homebrew cask automatically, with retry and concurrent-merge protection.

## 4.2.2 (build 9)

- Portal and summon requests that are refused, because a portal is already open or Rick is held mid-drag, no longer consume a voice line.
- Diagnostics no longer report a finished voice clip as still playing.
- Regression tests for the accepted and refused portal contract.
- Install documentation, demo animation, CI, tag-triggered release automation with a dry-run mode, and a Homebrew cask.
