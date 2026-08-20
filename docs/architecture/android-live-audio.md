# Android foreground live-audio implementation slice

**Status:** Experimental source implementation · **Last reviewed:** 2026-08-21 · **English (canonical)** · [Русский](android-live-audio_RU.md)

This document describes the source implementation bounded by the [Android foreground live-audio adapter v1 RFC](../../spec/android-live-audio-adapter-v1.md). It does not establish an Android target build, a granted runtime permission, an observed physical route, acoustic interoperability, device compatibility or support status.

## Implemented boundary

| Layer | Implemented responsibility | Not implemented or not established |
| --- | --- | --- |
| Rust core | Acoustic-1 encodes/decodes mono signed PCM16 LE directly, reusing its existing carrier/FEC/ADLP path. | Live timing recovery, AGC, echo cancellation, resampling or a physical-channel claim. |
| Rust bridge | Bounded text-to-live-PCM and captured-PCM-to-verified-text methods accept only `acoustic1`; bootstrap remains WAV-only. | File live PCM, unbounded stream decode or hardware access. |
| Flutter | A typed Android adapter validates v1 PCM, starts user-initiated playback/capture and passes capture frames to Rust only after the user stops capture. | ADLP/DSP in Dart, background operation, automatic resume, device picker or retained raw PCM. |
| Android host | `AudioTrack` streaming playback, `AudioRecord` capture, contextual `RECORD_AUDIO`, playback focus, stop/release on interruption/lifecycle stop, and an EventChannel for transient capture frames. | Bluetooth/cable/radio routing, `setPreferredDevice`, foreground service, duplex, Android device validation or support claim. |

The only encoded live object is a bounded text object using experimental `acoustic1`. Before `AudioTrack` starts, Flutter asks Rust to encode PCM and decodes the same in-memory PCM through Rust once as a codec boundary check. That check proves neither acoustic output nor receiver delivery.

```text
text → Rust ADLP + Acoustic-1 PCM → Flutter Android adapter → AudioTrack
                                                    │
AudioRecord → transient EventChannel PCM → Flutter → Rust Acoustic-1 + ADLP verification
```

Capture starts only after the user presses the Android capture control. The Kotlin host requests `RECORD_AUDIO` only then. On user stop, route/lifecycle stop or event cancellation, the host stops and releases native objects; Flutter discards the temporary PCM buffer after decode attempt. Playback requests focus immediately before `AudioTrack.play()` and stops/releases on focus loss. These choices implement the Android focus and permission constraints documented in the RFC. [1] [2] [3]

## Evidence state

The committed Rust tests, Flutter MethodChannel tests and portable widget tests exercise contract paths. They are not native Android or hardware tests. A target build, permission prompt, focus transition, capture device format, actual output route and speaker-to-microphone decode remain unverified until run on real hardware.

| Claim candidate | Current evidence | Permitted wording |
| --- | --- | --- |
| Rust live PCM conversion | Rust core/bridge unit tests | `source-tested PCM contract` |
| Flutter lifecycle mapping | Portable MethodChannel and widget tests | `source-tested adapter behavior` |
| Android compilation/runtime | None committed yet | No claim |
| Physical route | No measurement report | No claim |
| Platform or route support | No reviewed build and route evidence | No claim |

The [Android speaker-to-microphone template](../../tools/device-acceptance/fixtures/android-speaker-microphone-template-v1.json) remains unexecuted. A future real `physical_route` record must include the Android adapter observation fields enforced by the validator and must not retain or upload raw PCM by default.

## References

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)
