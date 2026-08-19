# Transmission presets

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](presets_RU.md)

A preset is a named parameter choice for a physical-layer profile. It expresses a user-facing speed-versus-reliability intent while the `profile_id` remains inside the ADLP object. The receiver reads the ID from the manifest; the sender does not need a separate out-of-band setting for basic profile selection.

## Reserved profile identifiers

| Profile ID | Preset | Intended route conditions | Bootstrap implementation |
| ---: | --- | --- | --- |
| `1` | Reliable | Noisy acoustic route, unknown gain or radio interface | Uses the shared bootstrap symbol mapper. |
| `2` | Balanced | Normal speaker/microphone or cable route | Uses the shared bootstrap symbol mapper. |
| `3` | Fast | Clean line route or reproducible WAV path | Uses the shared bootstrap symbol mapper. |
| `4` | Narrowband | Future radio-oriented profile | Uses the shared bootstrap symbol mapper. |

## Current limitation

The IDs are real protocol fields, but in the bootstrap release they do not yet change modulation, bit rate, coding or error correction. They are reserved now so future Acoustic-1 profile work can add distinct PHY behavior without changing the ADLP wire object or the user’s conceptual model.

## Future profile contract

Before a profile becomes selectable for live audio, its specification must define occupied band, nominal sample rate, framing, synchronization, coding/FEC behavior, preamble, acceptance metrics and golden test vectors. A UI label such as “Fast” is never sufficient as a compatibility definition.
