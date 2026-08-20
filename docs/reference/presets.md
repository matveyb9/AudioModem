# Transmission presets

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](presets_RU.md)

A preset is a named parameter choice for a physical-layer profile. It expresses a user-facing speed-versus-reliability intent while the `profile_id` remains inside the ADLP object. The receiver reads the ID from the manifest; the sender does not need a separate out-of-band setting for basic profile selection.

## Profile identifiers and controlled carrier behavior

| Profile ID | Preset | Bootstrap carrier | Experimental Acoustic-1 PCM/WAV carrier |
| ---: | --- | --- | --- |
| `1` | Reliable | Shared deterministic symbol mapper. | 480 samples/symbol, nominal 100 baud. |
| `2` | Balanced | Shared deterministic symbol mapper. | 240 samples/symbol, nominal 200 baud. |
| `3` | Fast | Shared deterministic symbol mapper. | 144 samples/symbol, nominal 333.3 baud. |
| `4` | Narrowband | Shared deterministic symbol mapper. | 480 samples/symbol, nominal 100 baud; this is not a radio narrowband compliance claim. |

## Current limitations

The deterministic bootstrap carrier still does not vary modulation, bit rate, coding or error correction by profile. The separate experimental Acoustic-1 carrier does vary the symbol window as shown above and applies fixed Hamming(7,4) FEC to its length and ADLP wire bytes. These controlled PCM/WAV facts do not establish a live acoustic reliability ranking for “Reliable”, “Balanced” or “Fast”.

## Future profile contract

Before a profile becomes selectable for live audio, its specification must define occupied band, nominal sample rate, framing, synchronization, coding/FEC behavior, preamble, acceptance metrics and golden test vectors. It must also have a route adapter and declared device measurements. A UI label such as “Fast” is never sufficient as a compatibility definition.
