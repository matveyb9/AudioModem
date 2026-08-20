# ADLP v1: bootstrap container and WAV transport

**Status:** Experimental. This document defines the ADLP v1 wire object and deterministic bootstrap path for automated tests and lossless WAV exchange. It is not an over-the-air acoustic PHY specification; the separate [Acoustic-1 experimental carrier](acoustic-1.md) has its own controlled-test scope.

## Layering

`TransferManifest + payload` are encoded into an ADLP wire object. The bootstrap codec maps this object to mono 48 kHz, 16-bit PCM WAV. The separate `Acoustic-1` codec also carries this unchanged wire object and replaces only the symbol mapper, not the ADLP bytes.

## ADLP wire object

All multi-byte integers are big-endian. The object ends with a CRC-32C over every preceding byte.

| Field | Size | Notes |
|---|---:|---|
| Magic | 4 bytes | ASCII `ADLP` |
| Protocol version | 1 byte | `1` |
| Profile ID | 1 byte | `1` Reliable, `2` Balanced, `3` Fast, `4` Narrowband |
| Object kind | 1 byte | `1` Text, `2` File |
| Session ID | 8 bytes | Sender-selected opaque value |
| Callsign | 1 + N bytes | UTF-8, N ≤ 32 |
| MIME type | 1 + N bytes | UTF-8, N ≤ 96 |
| File name | 1 + N bytes | UTF-8, N ≤ 160; empty for text |
| Payload length | 4 bytes | N ≤ 16 MiB |
| Payload | N bytes | Original text/file bytes |
| CRC-32C | 4 bytes | Castagnoli checksum |

A callsign is open metadata and is not an authentication mechanism. The future encryption envelope is intentionally outside this initial bootstrap format and will require an RFC.

## Bootstrap WAV carrier

The encoder writes canonical RIFF/WAVE, mono, PCM signed 16-bit, 48 kHz. A 64-bit alternating preamble is followed by sync word `0xD3A5`, 32-bit wire-object length, then the ADLP object. Each bit is represented by 24 constant samples: positive amplitude for `1`, negative amplitude for `0`. This profile is intentionally simple for reproducibility; it is not a robust acoustic modem waveform.

## Presets

The current `profile_id` travels in the manifest and is decoded automatically. In this bootstrap release, all presets use the same symbol mapper but retain distinct identifiers so UI and future PHY work can evolve without changing the container.
