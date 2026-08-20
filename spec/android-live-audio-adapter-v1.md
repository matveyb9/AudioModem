# Android foreground live-audio adapter v1

**Status:** Experimental source implementation · **English (canonical)** · [Русский](android-live-audio-adapter-v1_RU.md)

This RFC specializes the [constrained live-audio adapter v1](live-audio-adapter-v1.md) for a first Android implementation. Kotlin/Flutter/Rust source exists, but no Android target runtime or physical route has been verified. It does not establish a device result or make Android, speaker-to-microphone, cable, Bluetooth, headset or radio support claim.

## Scope

The initial target is **Android API 26 or later**, while the application is visible in the foreground and after an explicit user action. The adapter may perform one selected operation at a time:

| Operation | Native mechanism | Success boundary |
| --- | --- | --- |
| Playback | `AudioTrack` streaming writes of existing Rust-produced PCM | PCM was queued to an initialized track while audio focus was granted. It is not proof that another receiver decoded it. |
| Capture | `AudioRecord` reads of microphone PCM | PCM was read from an initialized record after permission grant. It is not proof that an ADLP object was acquired or decoded. |

The requested application format is the existing `PcmStreamFormat.audioModemV1`: **48,000 Hz, one channel, signed PCM16 little-endian**. The adapter must read back its effective record/track format and reject the operation when it cannot preserve that invariant. It must not silently resample, remix, substitute float PCM or fall back to another sample rate. Android documents `AudioRecord` as a pull interface and `AudioTrack` as a PCM-push interface; their buffers and configuration must be created and checked explicitly. [1] [2]

The adapter initially targets the OS-selected default capture/output path only. It does not call `setPreferredDevice()`, enumerate devices for a user selection, assert that a connected device is actually used, or support Bluetooth, cable, headset or radio-interface routing. A route-change notification terminates the active operation and records an observable diagnostic; it never implies successful rerouting. [1] [2]

## Permission, focus and lifecycle

The experimental source declares `RECORD_AUDIO`, but capture starts only after the user presses a capture action, the runtime permission is granted, and `AudioRecord` is initialized. The permission request must be contextual, cancellable and degrade to the existing WAV workflow when denied or revoked. [1] [3]

Playback requests `AudioFocusRequest` immediately before `AudioTrack.play()`. A denied focus request rejects the attempt. A delayed request remains pending and must not write/play PCM until focus is granted. Any permanent or transient focus loss, route change, user stop, record/track failure or application lifecycle stop terminates the operation; v1 never auto-resumes. Android’s focus guidance requires applications to react to focus loss and abandon focus when playback ends. [4]

```text
unavailable ──(API 26+ native adapter)──> idle
idle ──(user playback + granted focus + format verified)──> playing
idle ──(user capture + granted RECORD_AUDIO + format verified)──> capturing
idle ──(permission/focus/format failure)──> rejected ──(acknowledge)──> idle
playing|capturing ──(stop, focus loss, route change, lifecycle stop, native error)──> idle
any state ──(dispose)──> disposed
```

The current Flutter `LiveAudioAdapter` interface stays unchanged for this RFC. The experimental source exposes capture frames only through a bounded transient event stream; it must not expose unbounded raw microphone PCM as diagnostic data or make an unavailable adapter initialize Android audio APIs.

## Native operation rules

| Concern | Required behavior | Explicitly prohibited in v1 |
| --- | --- | --- |
| Capture | Build `AudioRecord` only after permission, use a buffer at least as large as the native minimum, verify initialized state, read bounded chunks, then stop and release. [1] | Background capture, retained ambient recordings, automatic retry after `ERROR_DEAD_OBJECT`, format fallback. |
| Playback | Build an initialized streaming `AudioTrack`, request/hold focus, write bounded chunks, stop, flush as appropriate, release and abandon focus. [2] [4] | Playback before focus, background/foreground-service playback, automatic resume, treating queued bytes as delivery. |
| Concurrent activity | Reject a second start while another operation is active. | Duplex operation, speaker-to-microphone loopback, echo cancellation or AGC. |
| Routing | Record the post-creation routed device category when observable; stop on a route change. | Declaring the requested/default/connected device to be a verified physical route. |
| Memory and privacy | Hold only operation buffers; discard captured PCM after hand-off or failure; retain textual diagnostics only. | Persisting raw PCM, callsigns or personal device identifiers automatically. |

## Diagnostics

Each operation produces a bounded, non-sensitive diagnostic record suitable for UI display and later acceptance reporting. It contains the adapter revision, Android API level, operation kind, requested/effective PCM format, initialization result, permission/focus outcome, route category if observable, stop reason, native error class and frame/byte counters. It excludes raw PCM, device serials, Bluetooth MAC addresses, user account names, callsigns and personal filesystem paths.

An accepted operation means only that the platform-side lifecycle completed according to this RFC. A decoder result, physical-route result and supported-route label require separate gates under the [device-acceptance protocol](../docs/operations/device-acceptance.md).

## Acceptance gates before enablement

| Gate | Required evidence | Insufficient evidence |
| --- | --- | --- |
| Build gate | Reproducible Android target build, native unit/integration tests and no hidden plugin initialization. | A Dart-only fake or a manifest declaration. |
| Permission gate | Tests for granted, denied and revoked microphone permission; denied capture leaves no `AudioRecord`. | A single successful permission prompt. |
| Format gate | Tests reject unavailable/mismatched actual PCM format and show requested/effective values. | Requesting 48 kHz without inspecting the created object. |
| Focus/interruption gate | Tests cover focus denied, delayed, transient loss, permanent loss and user stop with no auto-resume. | Calling `play()` without an observed focus result. |
| Route gate | A route-specific device-acceptance schema extension, validator fixtures and reviewed `physical_route` measurements for the exact Android scope. | A connected accessory, an emulator run or a schema-valid generic template. |

The first physical experiment may use only a declared `acoustic1` fixture and the existing report method once the route-specific evidence extension is merged. It must report all accepted, rejected and inconclusive runs. It may be labelled `observed` only after review, and it cannot create a broad Android compatibility claim.

## Non-goals

This RFC does not establish a supported implementation. It excludes Android API levels below 26, Web, iOS, Windows, macOS and Linux adapters; `MediaRecorder`; direct Rust microphone access; Bluetooth/cable/radio routing; device picker UI; background service; notification controls; persistence/history; duplex; echo cancellation; AGC; resampling; timing recovery changes; physical performance metrics; authentication; encryption; file transfer changes; and a supported-route claim.

## References

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[4] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)
