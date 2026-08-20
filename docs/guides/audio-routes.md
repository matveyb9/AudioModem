# Audio routes and transport boundaries

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](audio-routes_RU.md)

An AudioModem route delivers PCM samples. It does not define the data object. The ADLP object, frame integrity and selected profile must stay independent of whether the samples are saved, played, recorded or passed through another device. This is the design that allows delayed file exchange and a one-way radio path to use the same data-link layer.

## Route matrix

| Route | Delivery model | Bootstrap status | Requirement before “supported” |
| --- | --- | --- | --- |
| Lossless WAV | A file carries canonical PCM samples. | Implemented for text round trips and explicit local import/export in the Flutter workbench. | Acoustic interoperability observations across platforms and published fixture compatibility policy. |
| Controlled Acoustic-1 WAV | A file carries B-FSK PCM samples and the same ADLP v1 wire object. | Experimental: framing, bounded synchronisation, Hamming(7,4), profile-driven symbol windows and golden vector are implemented. | A route adapter plus declared speaker-to-microphone/device measurements. |
| Speaker → microphone | Local acoustic simplex path. | Planned. | Synchronization, level handling, FEC, noisy-room measurements and device tests. |
| Audio cable | Line-level PCM path. | Planned. | Device selection, sample-rate handling, gain guidance and cross-platform tests. |
| OS-managed Bluetooth | A selected audio input/output route. | Planned. | Per-platform permission/routing adapters and device compatibility testing. |
| Radio interface | External radio or transceiver audio path. | Planned. | Narrowband profile, radio-specific framing tests, lawful operating guidance and fixtures. |

## Transport independence

The encoder creates an ADLP object before it chooses a physical profile. A profile then turns that object into a PCM signal. An adapter can write this PCM stream to WAV, pass it to a playback device or accept it from a capture device. The receiver reverses these steps and does not expose payload data until object integrity checks pass.

```text
object → ADLP frame → selected PHY profile → PCM → route
route → PCM → selected PHY profile → ADLP frame → verified object
```

## Local WAV file workflow

The current Flutter workbench can save a verified in-memory WAV transfer through a user-selected save dialog and can select one `.wav` file through a local open dialog. The file adapter owns only the platform dialog and raw bytes. Every imported byte sequence is still passed to the Rust `decodeWav` bridge; the UI displays payload metadata only after framing, manifest and CRC-32C validation succeeds. Cancellation is not an error and does not create a transfer state.

The adapter relies on `file_picker`, whose documented API supports custom extension filters, byte reads and save-file dialogs across Android, iOS, Linux, macOS, Windows and web.[1] The adapter makes no claim that a file can be played over a speaker, captured from a microphone, routed through Bluetooth, or received from an audio cable.

## Acoustic-2 controlled measurements

Acoustic-2 is not an extra row in the route matrix. It is a repository-only measurement layer that parses an Acoustic-1 WAV, applies a declared integer PCM transform, re-encodes canonical WAV and calls the same Acoustic-1 decoder. Its result contains only input/output sample counts, dropped samples, bounded acquisition offset, consumed samples and decoded ADLP profile after a successful decode. The full order, parameter bounds and non-goals are fixed by the [Acoustic-2 contract](../../spec/acoustic-2.md).

Leading silence, attenuation, seeded additive noise, hard clipping and fixed periodic sample deletion are reproducible transform inputs, not measurements of a real channel. A result does not state SNR, BER, range, room-noise tolerance, clock drift, device behavior or live-route readiness.

## Golden compatibility fixture

`crates/audio-modem-core/tests/fixtures/adlp-v1-text-balanced.wav` is a fixed canonical fixture for ADLP v1 WAV bootstrap. `crates/audio-modem-core/tests/fixtures/acoustic-1-v1-text-balanced.wav` performs the same role for the experimental Acoustic-1 carrier. Their Rust regression tests decode the fixtures and compare whole byte sequences with fresh deterministic encodings of documented input objects. The same Acoustic-1 fixture also supplies the Acoustic-2 golden measurement vector, which locks declared transform parameters and codec-observable output values. Any byte or transform-result change is therefore a compatibility-affecting codec/harness change and must be reviewed with an updated fixture, hash or measurement rationale.

## Callsigns and privacy

A callsign is unencrypted display metadata in ADLP v1. It may be useful for a human operator but it is not identity proof. Future key exchange, encryption and signatures must be documented in a dedicated RFC and cannot be inferred from the presence of a callsign.

## Design rule for adapters

An adapter must report observable route facts—selected device, nominal sample rate, channel count, level or permission failure—without changing the ADLP object. Route diagnostics belong in the app’s event/reporting layer, while the codec remains deterministic and independently testable.

## References

[1]: https://pub.dev/packages/file_picker "file_picker package documentation"
