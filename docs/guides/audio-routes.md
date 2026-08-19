# Audio routes and transport boundaries

**Last reviewed:** 2026-08-19 · **English (canonical)** · [Русский](audio-routes_RU.md)

An AudioModem route delivers PCM samples. It does not define the data object. The ADLP object, frame integrity and selected profile must stay independent of whether the samples are saved, played, recorded or passed through another device. This is the design that allows delayed file exchange and a one-way radio path to use the same data-link layer.

## Route matrix

| Route | Delivery model | Bootstrap status | Requirement before “supported” |
| --- | --- | --- | --- |
| Lossless WAV | A file carries canonical PCM samples. | Implemented for text round trips. | Golden fixtures, documented CLI behavior and CI verification. |
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

## Callsigns and privacy

A callsign is unencrypted display metadata in ADLP v1. It may be useful for a human operator but it is not identity proof. Future key exchange, encryption and signatures must be documented in a dedicated RFC and cannot be inferred from the presence of a callsign.

## Design rule for adapters

An adapter must report observable route facts—selected device, nominal sample rate, channel count, level or permission failure—without changing the ADLP object. Route diagnostics belong in the app’s event/reporting layer, while the codec remains deterministic and independently testable.
