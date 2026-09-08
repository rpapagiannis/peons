# Character artwork

`rat-suit-pickle-rick-atlas.png` is the unmodified **Rat Suit Pickle Rick** sheet from **Pocket Mortys**, retrieved from [The Spriters Resource](https://www.spriters-resource.com/mobile/pocketmortys/asset/96322/).

Direct asset: https://www.spriters-resource.com/media/assets/93/96322.png?updated=1755476227

Rick and Morty, Pickle Rick, and the game artwork belong to their respective rights holders. This is an unofficial personal desktop companion; no ownership or redistribution license to the original game artwork is claimed.

The app selects the existing poses at runtime. It does not alter the source atlas. Four columns start at x = 5, 135, 265, 395. Front, left-side, and back rows start at y = 740, 907, 1075. Each crop is 125 × 160 pixels and excludes the cyan gutters. The left-side poses are mirrored for rightward movement.

The Peons app icon uses the large front-facing Rick portrait from the same Rat Suit Pickle Rick atlas, drawn over an original dark background. The icon shares the character artwork attribution above; the source atlas remains unmodified.


## Recorded Rick voice selection

The shipped voice selection combines the 14 Rick Sanchez recordings from [PeonPing/og-packs](https://github.com/PeonPing/og-packs/tree/v1.0.0/rick) with three signature Rick clips from [Rick and Morty clean](https://github.com/Mr3zee/peonping-rick-and-morty-clean/tree/v1.0.0). The upstream manifest in `sounds/rick/openpeon.json` describes the original 14-clip pack; `sounds/rick/lines.json` is the actual custom selection used by Peons.

The original recordings and their pinned upstream checksums remain in the source tree. Shipped clips are derived PCM WAV files with their levels balanced to a target of −20 dBFS RMS, limited to at least 3 dB of sample-peak headroom. No speech is synthesized, and no recordings are layered. `sounds/rick/normalization.json` records each source checksum, gain, output checksum, and measured levels. The sound rights remain with their respective owners; the original pack manifests retain their license and author metadata.

The comparison of the four available Rick-related packs is documented in `research/VOICE_PACKS.md` in the project source.

## Redistribution basis for this source repository

Checked 2026-09-08. Peons is a free, non-commercial personal project and credits both upstream sources above.

- The Spriters Resource describes itself as a fan archive "collected for personal projects and non-commercial work". Its Terms of Use state "Feel free to use the content as you wish (where legally permitted or in unpublished, non-commercial works)", prohibit use in commercial works and publication to established marketplaces such as Steam or the App Store, and ask that redistributed content credit its origin, which this file does.
- PeonPing distributes its sound packs publicly on GitHub (`PeonPing/og-packs`, MIT-licensed tooling, per-pack licenses in each `openpeon.json`). Its README states that sound files "are property of their respective publishers ... and are distributed under fair use for personal notification purposes". Both Rick packs used here declare CC-BY-NC-4.0, and the OpenPeon registry stores only metadata.

Neither source holds the underlying Rick and Morty or Pocket Mortys rights, so this documents the non-commercial, attributed basis for sharing the source tree; it is not a license from the rights holders.
