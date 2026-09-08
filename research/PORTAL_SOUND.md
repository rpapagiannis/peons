# Portal opening sound

The selected source is SoundboardGuy's [Rick and Morty portal sound](https://soundboardguy.com/sounds/rick-and-morty-portal-sound/), uploaded by zarak.khan81 and retrieved 2026-09-08. The [original MP3](https://soundboardguy.com/wp-content/uploads/2022/12/portal-gun-sound-effect.mp3) is retained at `assets/sounds/effects/portal_open.mp3`; `portal-audio-provenance.json` pins its SHA-256 and records attribution. Source identity follows the uploader's label; validation here covers decoded audio and playback behavior, not a subjective listening test.

## Preparation

Run `swift scripts/prepare_audio.swift` from the repository. The former voice-only script now prepares both voices and effects through the same function, offline, without playback. Existing voice WAVs are unchanged. Every original must match its recorded SHA-256 before conversion.

The portal recording receives one constant gain of −0.8996 dB: −19.1004 to −20.0000 dBFS RMS, with a final sample peak of −5.4771 dBFS. The script preserves all 137,088 frames, 48 kHz stereo format, and 2.856-second duration. It does not trim, synthesize, compress, or loop the sound. The 16-bit PCM WAV is decoded again to verify timing, format, RMS, and sample-peak headroom. Exact measurements and checksums are in `assets/sounds/effects/normalization.json`.

## Playback contract

- `PetModel.portal(to:)` counts only accepted openings. The controller consumes that count for both direct actions and free-roam updates, so each trip gets one opening cue. Animation ticks and the arrival midpoint do not replay it; refused requests do not restart it.
- P, the menu's portal action, and summoning all use the same controller path. Autonomous openings use the same event handler after the model step.
- `SoundPlayer` owns the sole `AVAudioPlayer`. An effect replaces any current voice; a later direct voice request can replace the effect. Neither creates a second audio channel. Effects clear the old caption and preserve the ordered voice cursor.
- The effect begins when the trip opens, and its full recorded tail can continue after the 0.85-second travel animation. The dialogue cooldown reserves the longer duration so idle chatter cannot interrupt it.
- `soundEnabled` and the existing `voiceVolume` preference apply to all recordings. Turning off occasional chatter affects idle voices only. Mute, hide, nap, sleep, and termination stop effects through the shared player. Silent openings are consumed without being replayed when sound or visibility returns.
- `effects/effects.json` supplies the asset path. Runtime lookup uses bundled resources first, then the local development assets. Builds copy only the normalized files referenced by the voice and effect manifests. There are no runtime downloads.
- Diagnostics retain `audioLine` for voices and add `audioEffect` for effects, plus `portalOpenCount`. A finished or stopped clip reports no active ID.

## Rights and attribution

See `assets/ATTRIBUTION.md`. The source page states no redistribution license. The voice packs' CC-BY-NC-4.0 declarations do not apply to this recording, and no underlying Rick and Morty rights are claimed.
