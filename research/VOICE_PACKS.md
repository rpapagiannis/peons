# Rat Suit Rick voice selection

Checked 2026-09-08 against the [live OpenPeon registry](https://peonping.github.io/registry/index.json), pinned upstream manifests, GitHub tags, and decoded local audio. This is an objective content/provenance and level comparison, **not a listening test**. Speaker fit follows upstream labels and descriptions; subjective intelligibility, background noise, and voice performance were not auditioned.

## Selection

Retain the 14 [PeonPing Rick Sanchez clips](https://openpeon.com/packs/rick) plus three Rick extras from [Mr3zee's clean pack](https://openpeon.com/packs/rick-and-morty-clean): `pickle_rick`, `i_turned_myself_into_a_pickle`, and `hey_morty`. These three now lead the ordered dialogue cycle; all 17 stable line IDs are unchanged. The choice preserves the short Rick-only collection and the Pickle Rick identity without importing a broad ensemble soundboard.

| Available pack | Pack version | Clips | Assessment for this character |
| --- | --- | ---: | --- |
| [Rick Sanchez](https://github.com/PeonPing/og-packs/tree/v1.0.0/rick) | 1.0.0 | 14 | Compact Rick foundation, without Pickle catchphrases. |
| [Rick and Morty clean](https://github.com/Mr3zee/peonping-rick-and-morty-clean/tree/v1.0.0) | 1.0.0 | 85 | Useful source for the three selected extras; the full pack includes other speakers, the screaming sun, and outro music. |
| [Rick and Morty NSFW](https://github.com/Mr3zee/peonping-rick-and-morty/tree/v1.0.0) | 1.0.0 | 107 | Broad collection with mature lines; no clear advantage for this focused selection. |
| [Rick C-137](https://github.com/maksym-fedorchuk-quarks-tech/peonping-rick-c137/tree/v1.0.0) | 1.0.0 | 24 | Short, curated Rick pack. It omits both Pickle catchphrases and five existing Rick one-liners; eight of its nine overlapping official clips are reencoded variants. |

At the time of the 2026-09-08 audit, the registry had 361 packs and pointed all four above to version 1.0.0. The OG repository has a newer overall release, v1.5.0, but its Rick manifest is byte-identical to the pinned v1.0.0 Rick manifest. The clean, NSFW, and C-137 repositories each still expose only their v1.0.0 tag. No newer Rick content release was missed.

C-137's manifest and website description misleadingly say all source sounds were merged; its actual 24-clip manifest, README, and current registry describe a curated selection. Its decoded RMS range is narrower than the original local mix, but replacing the pack would discard relevant content. All 24 comparison clips passed upstream checksum verification and decoded successfully.

## Level balancing

The three signature extras were much quieter than the official clips: approximately -25.55 to -28.72 dBFS RMS, versus -19.12 to -11.80 for the official 14. The selected recordings last 0.53–2.28 seconds, totaling 24.15 seconds.

`scripts/prepare_rick_voice.swift` applies one constant gain per clip toward **-20 dBFS RMS**, capped at a **-3.01 dBFS sample peak**. The extra 0.01 dB margin accommodates 16-bit conversion while preserving at least 3 dB of sample-peak headroom. It preserves duration, frames, sample rate, and channels; it does not trim, compress, denoise, or synthesize speech. RMS balancing is not perceptual LUFS normalization.

| Peak-capped clip | Final RMS dBFS | Reason |
| --- | ---: | --- |
| `i_turned_myself_into_a_pickle` | -20.17 | Preserve the peak ceiling. |
| `Rick_Sanchez_What_.mp3` | -20.97 | Preserve the peak ceiling. |
| `Rick_Sanchez_Drink_.mp3` | -22.06 | Preserve the peak ceiling. |

The remaining 14 clips reach -20 dBFS RMS within 0.02 dB. Every derived WAV was decoded again: no full-scale samples, maximum sample peak -3.0101 dBFS, and unchanged frames/rate/channels. A second preparation run reproduced all output WAVs and JSON byte-for-byte. The 17 derived PCM WAVs occupy 4,378,424 bytes.

Reproduce on macOS without network access or audio playback:

```sh
swift scripts/prepare_rick_voice.swift
```

The script checks each original MP3 against its pinned upstream SHA-256 before conversion. macOS audio decoding services must be accessible to the process. Original MP3 files remain unmodified in the source tree. `assets/sounds/rick/lines.json` is the actual playback inventory, referencing only `normalized/*.wav`. `normalization.json` records per-file original/output checksums, source URLs and commits, gains, decoded measurements, and validation. `openpeon.json` remains the original upstream 14-clip metadata for provenance; it is not the app's custom 17-clip playback inventory.

## Pinned source evidence

| Source | Commit at v1.0.0 | Manifest SHA-256 |
| --- | --- | --- |
| [PeonPing/og-packs Rick manifest](https://raw.githubusercontent.com/PeonPing/og-packs/v1.0.0/rick/openpeon.json) | `ec8630d43ae2cdb2af2617aa69a3df7737ec1c6d` | `c0097725338aa6d9f308d1948dbb60600105f5c10f8329c091e5f974758e42e1` |
| [Mr3zee clean manifest](https://raw.githubusercontent.com/Mr3zee/peonping-rick-and-morty-clean/v1.0.0/openpeon.json) | `125e30394baa24b70958e69ac7d87a6f5f401428` | `03ab40739b03d92e312301b459ed97f1d41cdbcd8df8328a5967e12ed4a27b03` |
| [Rick C-137 manifest](https://raw.githubusercontent.com/maksym-fedorchuk-quarks-tech/peonping-rick-c137/v1.0.0/openpeon.json) | `b47afaa8f6edcb0af9ff33fb3b0c09aa44b67010` | `7a14b0e4dc3c08a138a0dd4c8e9c163743db50b22965f96c3f817cdf3b8a72dd` |
| [Mr3zee NSFW manifest](https://raw.githubusercontent.com/Mr3zee/peonping-rick-and-morty/v1.0.0/openpeon.json) | `258089e44c579748895c21795fababd4ec83faab` | `2a78d38ff4dacfd861c8afbbdb4e23c08b4a93accb1e74c104aaa168f416209a` |

The first three manifests matched the existing research copies byte-for-byte. The selected original 17 MP3s matched the source checksums in `research/rick-audio-provenance.json`. Upstream fan packs identify CC-BY-NC-4.0; original Rick and Morty audio remains the property of its respective rights holders. Level balancing does not grant additional rights to that audio.
