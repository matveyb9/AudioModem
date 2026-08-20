# Flutter ↔ Rust WAV bridge

**Last reviewed:** 2026-08-21 · **English (canonical)** · [Русский](flutter-rust-bridge_RU.md)

The native bridge exposes Rust ADLP plus two controlled WAV codecs to Flutter: deterministic bootstrap and experimental Acoustic-1. The app has a separate local file adapter for selecting or saving WAV bytes, while the bridge itself still does not introduce audio capture, playback, Bluetooth, background transmission or encryption. Its purpose is to make one real app-to-core round trip observable and testable without duplicating protocol or codec logic in Dart.

## Boundary

```text
Flutter workbench → generated Dart API → audio_modem_bridge → audio-modem-core + adlp-protocol
```

The bridge crate is a thin native facade. `adlp-protocol` remains responsible for the versioned object and CRC-32C. `audio-modem-core` remains responsible for deterministic PCM/WAV encoding and decoding. Generated code is glue only and must not contain protocol decisions.

## Public contract

| Operation | Input | Output | Failure behavior |
| --- | --- | --- | --- |
| `encodeTextToWav` | Positive `sessionId`, callsign, UTF-8 text, profile and explicit carrier (`bootstrap` or `acoustic1`) | Canonical 48 kHz mono 16-bit WAV bytes and transfer metadata | A typed Rust error becomes a Dart exception; no partial WAV is returned. |
| `decodeWav` | WAV bytes from memory and explicit carrier | Verified text metadata, UTF-8 payload, sample rate and consumed samples | Wrong-carrier, framing, manifest or CRC-32C failure becomes an exception; no payload is returned. |
| `encodeFileToWav` | Positive `sessionId`, callsign, leaf file name, declared MIME type, bounded bytes, profile and explicit carrier | Canonical 48 kHz mono 16-bit WAV bytes and transfer metadata | Invalid metadata or an oversized payload becomes a Dart exception; no partial WAV is returned. |
| `decodeWavFile` | WAV bytes from memory and explicit carrier | Verified file metadata, original bytes, sample rate and consumed samples | A text object, wrong-carrier, framing, manifest or CRC-32C failure becomes an exception; no file bytes are returned. |

The Flutter app chooses the session value in this first slice. The screen uses a positive timestamp-derived value only as local transfer metadata; it is not a timestamp claim, identity claim or cryptographic nonce.

## File adapter boundary

`PlatformWavFileAdapter` opens local platform dialogs and returns opaque WAV bytes or submits a verified in-memory buffer for saving. `PlatformPayloadFileAdapter` separately selects a local outbound file or saves only bytes returned by `decodeWavFile`. Neither adapter parses waveforms, decides protocol validity, infers a MIME type from received bytes, or reads a payload before Rust validation. The workbench tries a typed text decoder and then a typed file decoder for an imported WAV; a failed decode retains no received object. This keeps user filesystem interaction outside the deterministic protocol and codec boundary.

## Carriers, profiles and limits

The bridge accepts `bootstrap` and `acoustic1` carriers. Bootstrap retains one deterministic symbol mapper for every profile. Acoustic-1 has a separate B-FSK mapper with profile-dependent symbol windows, Hamming(7,4), bounded frame acquisition and a 256-byte ADLP wire-object limit; its exact compatibility contract is in the [Acoustic-1 RFC](../../spec/acoustic-1.md). The UI keeps a carrier selection with an explicit experimental notice and reuses that selection for import, export and verification.

The bridge accepts `reliable`, `balanced`, `fast` and `narrowband`, which map directly to ADLP profile IDs 1–4. The native facade rejects text or file payloads longer than **8 KiB** before WAV allocation. This lower application limit protects a mobile or desktop UI from accidentally creating impractically large buffers while the general protocol limit remains larger for future profiles.

## Native integration smoke check

Widget tests use fakes to keep the normal Flutter suite portable. A separate opt-in Linux smoke test loads the shared library from the freshly built bundle, calls the real generated bridge, round-trips a bounded file object and checks a wrong-carrier rejection.

```bash
export PATH="/home/ubuntu/.local/flutter/bin:$HOME/.cargo/bin:$PATH"
cd apps/audio_modem
flutter build linux --debug
AUDIOMODEM_RUN_NATIVE_BRIDGE_SMOKE=1 \
  LD_LIBRARY_PATH="$PWD/build/linux/x64/debug/bundle/lib" \
  flutter test test/native_bridge_smoke_test.dart
```

This check proves the native application-to-core binding for the documented fixture. It does not test a microphone, speaker, cable, Bluetooth path, radio interface or any live route.

## Trust boundary

A callsign is open display metadata. The bridge does not promise authentication, confidentiality or an identity association. Key exchange, encrypted payloads and signature verification belong to a separate, reviewed future API and RFC.

## Generated code policy

`flutter_rust_bridge` generated source is committed so a fresh clone can build without local code generation. The repository also keeps the generator configuration and regeneration command. Hand-written Flutter code may call generated API methods but may not edit generated files.
