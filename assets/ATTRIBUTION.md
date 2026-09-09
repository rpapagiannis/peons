# Character artwork

`rat-suit-pickle-rick-atlas.png` is the unmodified **Rat Suit Pickle Rick** sheet from **Pocket Mortys**, retrieved from [The Spriters Resource](https://www.spriters-resource.com/mobile/pocketmortys/asset/96322/).

Direct asset: https://www.spriters-resource.com/media/assets/93/96322.png?updated=1755476227

Rick and Morty, Pickle Rick, and the game artwork belong to their respective rights holders. This is an unofficial personal desktop companion; no ownership or redistribution license to the original game artwork is claimed.

The app selects the existing poses at runtime. It does not alter the source atlas. Four columns start at x = 5, 135, 265, 395. Front, left-side, and back rows start at y = 740, 907, 1075. Each crop is 125 × 160 pixels and excludes the cyan gutters. The left-side poses are mirrored for rightward movement.

The Peons app icon uses the large front-facing Rick portrait from the same Rat Suit Pickle Rick atlas, drawn over an original dark background. The icon shares the character artwork attribution above; the source atlas remains unmodified.

## Warcraft Peon artwork

`warcraft-peon-sheet.png` is the unmodified **Peon** sheet from **Warcraft II** (MS-DOS), uploaded by **Maxim** to [The Spriters Resource](https://www.spriters-resource.com/ms_dos/warcraftii/asset/29480/), retrieved 2026-09-09. [Direct PNG](https://www.spriters-resource.com/media/assets/27/29480.png?updated=1755472636). Warcraft and its artwork belong to Blizzard Entertainment.

The original 255 × 1017 RGBA sheet has SHA-256 `fee05cc9b6b92c666990102ae74a1bc2f6baca8b254bde57088d167f13f960a7`. Its magenta/white gutters already have zero alpha. The source directions run north, northeast, east, southeast, south. The app crops front, side, and back sequences from x = 203, 108, 5, with five poses at y = 0, 38, 79, 120, 161. Each crop is 46 × 38; pose 0 is idle and poses 1–4 form the walk cycle. The right-facing side view is mirrored for leftward movement. No credits, working/carrying poses, or adjacent sprites enter these crops.

Rendering preserves the original aspect ratio at 5× source pixels within the shared canvas, with nearest-neighbor sampling. Per-pose foot offsets in `Sources/Characters.swift` compensate for transparent padding so the feet meet the same physical floor as Rick. Artwork tests verify all 15 crops and both directions of the rendered walk cycle. Source pixels remain unchanged.

## Recorded Warcraft Peon voices

The complete 17-clip English **Orc Peon** pack (Warcraft III), version **1.1.0**, comes from [PeonPing/og-packs](https://github.com/PeonPing/og-packs/tree/5d1245fe0188c8da775ca8875c32ee7bf8d92c57/peon), pinned to commit `5d1245fe0188c8da775ca8875c32ee7bf8d92c57` on 2026-09-09. The upstream pack credits **tonyyont** and declares **CC-BY-NC-4.0**; the underlying recordings belong to Blizzard Entertainment. This records the fan pack's declaration without claiming a license from Blizzard.

`sounds/peon/openpeon.json` retains the upstream manifest verbatim. The original WAVs match every upstream SHA-256; `research/peon-audio-provenance.json` records their pinned URLs and checksums. `sounds/peon/lines.json` is the app's complete ordered playback inventory, beginning with Ready to work, Work work, Something need doing, and Okie dokie. Each character retains its own cycle when switching.

As with Rick, `scripts/prepare_audio.swift` prepares derived PCM WAVs toward −20 dBFS RMS with at least 3 dB sample-peak headroom, preserving duration, channels, rate, and frames. `sounds/peon/normalization.json` records the measurements, gains, and checksums. Only the normalized files are bundled for playback; original recordings stay in the source tree.


## Recorded Rick voice selection

The shipped voice selection combines the 14 Rick Sanchez recordings from [PeonPing/og-packs](https://github.com/PeonPing/og-packs/tree/v1.0.0/rick) with three signature Rick clips from [Rick and Morty clean](https://github.com/Mr3zee/peonping-rick-and-morty-clean/tree/v1.0.0). The upstream manifest in `sounds/rick/openpeon.json` describes the original 14-clip pack; `sounds/rick/lines.json` is the actual custom selection used by Peons.

The original recordings and their pinned upstream checksums remain in the source tree. Shipped clips are derived PCM WAV files with their levels balanced to a target of −20 dBFS RMS, limited to at least 3 dB of sample-peak headroom. No speech is synthesized, and no recordings are layered. `sounds/rick/normalization.json` records each source checksum, gain, output checksum, and measured levels. The sound rights remain with their respective owners; the original pack manifests retain their license and author metadata.

The comparison of the four available Rick-related packs is documented in `research/VOICE_PACKS.md` in the project source.

## Recorded portal effect

`sounds/effects/normalized/portal_open.wav` is derived from the [Rick and Morty portal sound](https://soundboardguy.com/sounds/rick-and-morty-portal-sound/) uploaded to SoundboardGuy by **zarak.khan81**, retrieved 2026-09-08. [Original MP3](https://soundboardguy.com/wp-content/uploads/2022/12/portal-gun-sound-effect.mp3).

The original MP3 and its SHA-256 remain in the source tree, with provenance in `research/portal-audio-provenance.json`. The effect uses the same preparation function as the voices: one constant gain toward −20 dBFS RMS, with at least 3 dB sample-peak headroom. Duration, sample rate, channels, and frame count are preserved. `sounds/effects/normalization.json` records the input/output checksums and measurements. `sounds/effects/effects.json` is its playback inventory.

The source page offers a download but states no redistribution license for this fan-uploaded recording. No ownership or license to the underlying Rick and Morty audio is claimed; its rights remain with their respective owners. This effect is not covered by the voice packs' CC-BY-NC-4.0 declarations.

## Redistribution basis for this source repository

Checked 2026-09-08. Peons is a free, non-commercial personal project and credits both upstream sources above.

- The Spriters Resource describes itself as a fan archive "collected for personal projects and non-commercial work". Its Terms of Use state "Feel free to use the content as you wish (where legally permitted or in unpublished, non-commercial works)", prohibit use in commercial works and publication to established marketplaces such as Steam or the App Store, and ask that redistributed content credit its origin, which this file does.
- PeonPing distributes its sound packs publicly on GitHub (`PeonPing/og-packs`, MIT-licensed tooling, per-pack licenses in each `openpeon.json`). Its README states that sound files "are property of their respective publishers ... and are distributed under fair use for personal notification purposes". Both Rick packs used here declare CC-BY-NC-4.0, and the OpenPeon registry stores only metadata.

Neither source holds the underlying Rick and Morty or Pocket Mortys rights, so this documents the non-commercial, attributed basis for sharing the source tree; it is not a license from the rights holders.
