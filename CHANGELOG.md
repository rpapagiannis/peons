# Changelog

After CI passes on `main`, the release workflow advances the build number and moves Unreleased entries into `## <version> (build <build>)`, then copies that section into the GitHub release notes.

## Unreleased

- Rick now makes occasional high jumps and opens portals to clearly separated floor destinations while roaming freely, including across monitors.
- Autonomous actions wait for throws and landings, pause for hovering and interaction, and leave room to catch Rick before resuming. Existing voice and chatter preferences still apply.
- Deterministic regression coverage for free-roam behavior, interruption, cooldowns, and desktop geometry.
- Successful merges to `main` now create a versioned release and update the Homebrew cask automatically, with retry and concurrent-merge protection.

## 4.2.2 (build 9)

- Portal and summon requests that are refused, because a portal is already open or Rick is held mid-drag, no longer consume a voice line.
- Diagnostics no longer report a finished voice clip as still playing.
- Regression tests for the accepted and refused portal contract.
- Install documentation, demo animation, CI, tag-triggered release automation with a dry-run mode, and a Homebrew cask.
