# Changelog

The release workflow copies the section whose heading matches the pushed tag, `## <version> (build <build>)`, into the GitHub release notes.

## 4.2.2 (build 9)

- Portal and summon requests that are refused, because a portal is already open or Rick is held mid-drag, no longer consume a voice line.
- Diagnostics no longer report a finished voice clip as still playing.
- Regression tests for the accepted and refused portal contract.
- Install documentation, demo animation, CI, tag-triggered release automation with a dry-run mode, and a Homebrew cask.
