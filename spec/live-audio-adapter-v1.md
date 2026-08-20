# Constrained live-audio adapter v1

**Status:** Draft implementation contract · **English (canonical)** · [Русский](live-audio-adapter-v1_RU.md)

This RFC defines the application boundary for a future live audio route. It does not add capture, playback, microphone permission, audio focus, device enumeration, cable routing, Bluetooth routing, radio support or a supported platform. The initial implementation provides an unavailable adapter only, so the UI and tests can distinguish a designed interface from a functioning route.

## Scope and first-route constraint

The first physical route, if and only if it is separately approved, will be **one local speaker-to-microphone simplex path** with a single documented platform/device scope. It may carry one selected ADLP carrier as raw mono PCM16 frames. A route RFC, platform implementation, complete device-acceptance evidence and target-specific tests must exist before that adapter is enabled.

The v1 contract does not select a Flutter recording/playback package. Flutter guidance shows that permission, capture configuration, stream control and disposal are separate responsibilities; platform support varies by encoding and target.[1] Session configuration and focus ownership are likewise platform-specific, including app-wide iOS session behavior and Android per-track attributes.[2] [3]

## Typed contract

The Flutter-facing interface has three concerns.

| Type | Responsibility | Required invariant |
| --- | --- | --- |
| `PcmStreamFormat` | Describes future raw frames: sample rate, channels and sample format. | V1 accepts only `48,000 Hz`, mono, signed PCM16 little-endian. WAV containers are not accepted. |
| `LiveAudioAvailability` | Reports whether a concrete adapter is enabled and why not. | `isAvailable == false` must never imply permission, capture, playback or device discovery. |
| `LiveAudioAdapter` | Reserves `startPlayback`, `startCapture` and `stop` lifecycle commands. | A command may begin only after a platform adapter has verified format, permission and session/focus activation. |

An unavailable adapter must return a failed future for every lifecycle command with the same public reason it exposes in `availability`. It must not request a permission, initialize a plugin, access a microphone, enumerate hardware, emit captured bytes or play audio.

## Lifecycle and state boundary

The contract names states but does not implement a route state machine yet.

```text
unavailable ──(approved platform adapter)──> idle
idle ──(permission + session/focus granted)──> active playback | active capture
active ──(interrupt/route change/user stop)──> idle
any state ──(dispose)──> disposed
```

The future adapter is responsible for converting native permission, audio-session/focus, interruption and route-change signals into truthful failure or stop events. It must not automatically resume after an interruption in v1. On Android, focus may be denied or delayed and should be handled before output begins; on iOS audio-session settings are shared across the app, so adapter/plugin ownership must be declared before activation.[2] [3]

## Required future acceptance gates

| Gate | Required before enabling a route | Insufficient evidence |
| --- | --- | --- |
| Contract gate | This RFC, a typed adapter, unavailable behavior tests and no hidden plugin initialization. | A dependency listed in `pubspec.yaml`. |
| Platform gate | One approved platform implementation with permission/session/focus handling and a reproducible native build. | A generic cross-platform interface. |
| Device gate | Reviewed `physical_route` reports under the [device-acceptance protocol](../docs/operations/device-acceptance.md), including fixture hashes, route settings and failures. | A schema-valid template or a controlled Acoustic-2 result. |
| Route gate | Target-specific integration tests, documented limits and maintainer approval. | A successful run on an undocumented device. |

## Security and privacy

Live routes can capture private ambient audio. The adapter must be opt-in, should minimize retained audio, and must not persist raw frames or callsigns automatically. Any device report follows the recording availability and privacy rules in the device-acceptance protocol. Encryption remains separate from route transport and is not implied by a live adapter.

## Non-goals

This RFC does not provide automatic gain control, echo cancellation, resampling, timing recovery, FEC changes, duplex mode, background execution, Bluetooth/cable/radio routing, device discovery, audio visualization, Web Audio, microphone permission UI, playback, capture or physical interoperability.

## References

[1]: https://docs.flutter.dev/cookbook/audio/record "Record or stream audio input"
[2]: https://pub.dev/packages/audio_session "audio_session package documentation"
[3]: https://developer.android.com/media/optimize/audio-focus "Manage audio focus"
