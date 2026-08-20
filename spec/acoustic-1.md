# Acoustic-1: experimental audio PHY

**Status:** Experimental draft · **Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](acoustic-1_RU.md)

Acoustic-1 is the first AudioModem physical-layer profile intended for controlled PCM/WAV experiments. It carries an unchanged ADLP v1 wire object and is not a claim of speaker-to-microphone, radio, Bluetooth, or cross-device compatibility. The deterministic bootstrap carrier remains the reference transport for lossless tests; Acoustic-1 is a separate carrier with explicit framing and bounded error tolerance.

## Scope and compatibility

| Item | Acoustic-1 rule |
| --- | --- |
| Input and final integrity | An ADLP v1 wire object, including its existing CRC-32C. |
| Sample shape | Canonical RIFF/WAVE, mono, signed 16-bit PCM, 48 kHz. |
| Modulation | Binary FSK: one mark tone for `1`, one space tone for `0`. |
| FEC | Hamming(7,4) applied to length and wire-object nibbles. |
| Object limit | At most 256 encoded ADLP wire bytes per frame. |
| Carrier version | Acoustic-1 is selected by codec API; it does not alter the ADLP v1 version byte. |

Binary FSK with a preamble, sync word, payload and final integrity check follows the structure of practical modem designs.[1] Acoustic-1 uses a non-coherent two-tone energy comparison rather than carrier-phase recovery, consistent with the distinction between coherent and non-coherent FSK detection.[2]

> **Compatibility rule:** A decoder MUST not expose a received object until Hamming decoding, frame bounds, ADLP decoding and ADLP CRC-32C validation have all succeeded.

## Signal parameters

The encoder resets the phase at every symbol boundary. Samples use an integer 48-step sine table at an amplitude of `12,000`, avoiding floating-point dependence in encoded golden vectors. Mark uses 1,000 Hz and space uses 2,000 Hz; these are integer harmonics of the 48 kHz sample rate.

| ADLP profile | Samples per symbol | Nominal symbol rate | Intended trade-off |
| --- | ---: | ---: | --- |
| `reliable` | 480 | 100 baud | More energy per bit. |
| `balanced` | 240 | 200 baud | Default controlled-test profile. |
| `fast` | 144 | 333.3 baud | Shorter symbol window; lower expected noise margin. |
| `narrowband` | 480 | 100 baud | Conservative profile identifier; this is **not** a radio narrowband compliance claim. |

The profile travels inside the ADLP manifest. A decoder tries the fixed Acoustic-1 profile configurations, then MUST reject a frame if the recovered manifest profile does not equal the configuration that decoded it.

## Frame layout

Each entry below is transmitted most-significant bit first. The `wire_length` and ADLP wire object are FEC-protected; preamble and sync are raw symbols so the receiver can obtain frame alignment before applying FEC.

| Field | Symbols | Encoding |
| --- | ---: | --- |
| Preamble | 64 | Alternating `1, 0, 1, 0, …`, beginning with `1`. |
| Sync | 16 | Raw `0xD391`. |
| Wire length | 56 | Four big-endian length bytes; each 4-bit nibble becomes one Hamming(7,4) codeword. |
| ADLP wire object | `14 × N` | Every byte is split into two nibbles; each nibble becomes one Hamming(7,4) codeword. |

The object limit avoids unbounded WAV allocation. At 200 baud, the FEC payload rate is approximately 14.3 encoded wire bytes per second before the preamble and sync; large files require a later packetisation design.

## Hamming(7,4) mapping

Acoustic-1 uses positions `1..7` in this order: `p1, p2, d3, p4, d2, d1, d0`. For a nibble `d3 d2 d1 d0`, parity is even and is calculated as follows:

```text
p1 = d3 XOR d2 XOR d0
p2 = d3 XOR d1 XOR d0
p4 = d2 XOR d1 XOR d0
```

The decoder derives a three-bit syndrome and flips the indexed position when that syndrome is in `1..7`. Hamming block codes correct one bit error per codeword; they are not a replacement for end-to-end integrity, which remains the ADLP CRC-32C.[3] A two-bit corruption can be miscorrected, so a decoder must treat a failed ADLP CRC as a failed frame rather than returning payload.

## Receiver algorithm

The receiver parses canonical 48 kHz PCM WAV, then evaluates each declared profile configuration. It scans only the first 480 PCM samples for a frame start; this explicitly supports a bounded leading-silence/timing offset, not arbitrary timing recovery. For each candidate symbol window, it calculates in-phase and quadrature correlation energy against the fixed mark and space references, then chooses the higher energy. A candidate succeeds only if its preamble and sync match, the FEC length is within 256 bytes, its ADLP object validates, and its manifest profile equals the tried configuration.

This bounded synchronisation rule is intentional. A documented FSK implementation warns that free-running blocks need close symbol-boundary alignment.[1] Future Acoustic revisions must add timing recovery, level estimation, band-pass filtering, interleaving and device measurements before any live-route support claim.

## Required regression evidence

The implementation must keep deterministic tests for all four ADLP profile identifiers, a leading-silence offset no greater than 480 samples, one corrected Hamming codeword error, an invalid double-corruption rejection through ADLP integrity, and bounded additive sample noise. An Acoustic-1 golden fixture must be decoded and regenerated byte-for-byte from its documented ADLP object.

## Non-goals

Acoustic-1 does not provide encryption, authentication, replay protection, packet segmentation, ARQ, live playback/capture, AGC, echo cancellation, Bluetooth routing, radio compliance, or a cross-device acoustic success guarantee.

## References

[1]: https://tinytapeout.com/chips/ttgf26a/tt_um_hydrocomms "FSK Modem — Tiny Tapeout"
[2]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[3]: https://liquidsdr.org/doc/fec/ "liquid-dsp forward error-correction documentation"
