# Flutter ↔ Rust WAV bridge

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](flutter-rust-bridge_RU.md)

The first native bridge exposes the existing Rust ADLP and WAV bootstrap implementation to Flutter. It does not introduce audio capture, playback, Bluetooth, files selected by the user, background transmission or encryption. Its purpose is to make one real app-to-core round trip observable and testable without duplicating protocol or codec logic in Dart.

## Boundary

```text
Flutter workbench → generated Dart API → audio_modem_bridge → audio-modem-core + adlp-protocol
```

The bridge crate is a thin native facade. `adlp-protocol` remains responsible for the versioned object and CRC-32C. `audio-modem-core` remains responsible for deterministic PCM/WAV encoding and decoding. Generated code is glue only and must not contain protocol decisions.

## Public contract

| Operation | Input | Output | Failure behavior |
| --- | --- | --- | --- |
| `encodeTextToWav` | Positive `sessionId`, callsign, UTF-8 text, profile | Canonical 48 kHz mono 16-bit WAV bytes and transfer metadata | A typed Rust error becomes a Dart exception; no partial WAV is returned. |
| `decodeWav` | WAV bytes from memory | Verified text metadata, UTF-8 payload, sample rate and consumed samples | Framing, manifest or CRC-32C failure becomes an exception; no payload is returned. |

The Flutter app chooses the session value in this first slice. The screen uses a positive timestamp-derived value only as local transfer metadata; it is not a timestamp claim, identity claim or cryptographic nonce.

## Profiles and limits

The bridge accepts `reliable`, `balanced`, `fast` and `narrowband`, which map directly to ADLP profile IDs 1–4. In the bootstrap codec these IDs do not yet alter PCM modulation or error correction. The native facade rejects text longer than **8 KiB** before WAV allocation. This lower application limit protects a mobile or desktop UI from accidentally creating impractically large bootstrap WAV buffers while the general protocol limit remains larger for future profiles.

## Trust boundary

A callsign is open display metadata. The bridge does not promise authentication, confidentiality or an identity association. Key exchange, encrypted payloads and signature verification belong to a separate, reviewed future API and RFC.

## Generated code policy

`flutter_rust_bridge` generated source is committed so a fresh clone can build without local code generation. The repository also keeps the generator configuration and regeneration command. Hand-written Flutter code may call generated API methods but may not edit generated files.
