# Android foreground live-audio adapter v1

[English (canonical)](android-live-audio-adapter-v1.md) · **Русский перевод**

> **Translation of:** [spec/android-live-audio-adapter-v1.md](android-live-audio-adapter-v1.md). **Last synced:** 2026-08-21.

**Статус:** Draft experimental platform-route design. Это не включает Android audio, не устанавливает device result и не заявляет Android, speaker-to-microphone, cable, Bluetooth, headset или radio support.

## Scope

Initial target — **Android API 26 или выше**, пока application visible в foreground и после explicit user action. Adapter выполняет только одну selected operation одновременно.

| Операция | Native mechanism | Success boundary |
| --- | --- | --- |
| Playback | `AudioTrack` streaming writes существующего Rust-produced PCM | PCM queued в initialized track, пока audio focus granted. Это не доказывает, что другой receiver его decoded. |
| Capture | `AudioRecord` reads microphone PCM | PCM прочитан из initialized record после permission grant. Это не доказывает, что ADLP object acquired или decoded. |

Requested application format — существующий `PcmStreamFormat.audioModemV1`: **48,000 Hz, one channel, signed PCM16 little-endian**. Adapter читает effective record/track format и отклоняет operation, если invariant не сохранён. Он не может silently resample, remix, substitute float PCM или fallback на другой sample rate. Android описывает `AudioRecord` как pull interface, а `AudioTrack` как PCM-push interface; их buffers и configuration создаются и проверяются явно. [1] [2]

Первый adapter использует только OS-selected default capture/output path. Он не вызывает `setPreferredDevice()`, не enumerates devices для user selection, не утверждает, что connected device действительно используется, и не поддерживает Bluetooth, cable, headset или radio-interface routing. Route-change notification завершает active operation и записывает observable diagnostic; он не означает successful rerouting. [1] [2]

## Permission, focus и lifecycle

`RECORD_AUDIO` объявляется только когда этот RFC станет approved implementation change. Capture начинается лишь после нажатия user capture action, runtime permission grant и initialized `AudioRecord`. Permission request должен быть contextual и cancellable, а после denial или revocation application деградирует к существующему WAV workflow. [1] [3]

Playback запрашивает `AudioFocusRequest` непосредственно перед `AudioTrack.play()`. Denied focus request отклоняет attempt. Delayed request остаётся pending и не может write/play PCM до focus grant. Permanent или transient focus loss, route change, user stop, record/track failure или application lifecycle stop завершает operation; v1 никогда auto-resume. Android focus guidance требует реакции на focus loss и abandon focus после playback end. [4]

```text
unavailable ──(API 26+ native adapter)──> idle
idle ──(user playback + granted focus + format verified)──> playing
idle ──(user capture + granted RECORD_AUDIO + format verified)──> capturing
idle ──(permission/focus/format failure)──> rejected ──(acknowledge)──> idle
playing|capturing ──(stop, focus loss, route change, lifecycle stop, native error)──> idle
any state ──(dispose)──> disposed
```

Текущий Flutter `LiveAudioAdapter` interface для этого RFC не меняется. Later implementation может показать platform diagnostics через отдельный event stream или status object, но не должен exposing unbounded raw microphone PCM как diagnostic data или заставлять unavailable adapter инициализировать Android audio APIs.

## Native operation rules

| Concern | Required behavior | Явно запрещено в v1 |
| --- | --- | --- |
| Capture | Создать `AudioRecord` только после permission, использовать buffer не меньше native minimum, verify initialized state, читать bounded chunks, затем stop и release. [1] | Background capture, retained ambient recordings, automatic retry после `ERROR_DEAD_OBJECT`, format fallback. |
| Playback | Создать initialized streaming `AudioTrack`, request/hold focus, писать bounded chunks, stop, flush при необходимости, release и abandon focus. [2] [4] | Playback до focus, background/foreground-service playback, automatic resume, трактовка queued bytes как delivery. |
| Concurrent activity | Отклонять второй start, пока другая operation active. | Duplex, speaker-to-microphone loopback, echo cancellation или AGC. |
| Routing | Записывать post-creation routed device category, если observable; stop при route change. | Заявлять requested/default/connected device verified physical route. |
| Memory и privacy | Хранить только operation buffers; discard captured PCM после hand-off или failure; retain только textual diagnostics. | Автоматическое persistence raw PCM, callsigns или personal device identifiers. |

## Diagnostics

Каждая operation создаёт bounded, non-sensitive diagnostic record для UI и later acceptance reporting. Он содержит adapter revision, Android API level, operation kind, requested/effective PCM format, initialization result, permission/focus outcome, route category при observable, stop reason, native error class и frame/byte counters. Он исключает raw PCM, device serials, Bluetooth MAC addresses, user account names, callsigns и personal filesystem paths.

Accepted operation означает только platform-side lifecycle completion согласно этому RFC. Decoder result, physical-route result и supported-route label требуют separate gates из [device-acceptance protocol](../docs/operations/device-acceptance_RU.md).

## Acceptance gates before enablement

| Gate | Required evidence | Insufficient evidence |
| --- | --- | --- |
| Build gate | Reproducible Android target build, native unit/integration tests и no hidden plugin initialization. | Dart-only fake или manifest declaration. |
| Permission gate | Tests для granted, denied и revoked microphone permission; denied capture не создаёт `AudioRecord`. | Один successful permission prompt. |
| Format gate | Tests отклоняют unavailable/mismatched actual PCM format и показывают requested/effective values. | Request 48 kHz без inspect created object. |
| Focus/interruption gate | Tests покрывают focus denied, delayed, transient loss, permanent loss и user stop без auto-resume. | Вызов `play()` без observed focus result. |
| Route gate | Route-specific device-acceptance schema extension, validator fixtures и reviewed `physical_route` measurements для exact Android scope. | Connected accessory, emulator run или schema-valid generic template. |

Первый physical experiment использует только declared `acoustic1` fixture и existing report method после merge route-specific evidence extension. Он сообщает все accepted, rejected и inconclusive runs. Label `observed` возможен только после review и не создаёт broad Android compatibility claim.

## Non-goals

Этот RFC ещё не одобряет implementation. Он исключает Android API ниже 26, Web, iOS, Windows, macOS и Linux adapters; `MediaRecorder`; direct Rust microphone access; Bluetooth/cable/radio routing; device picker UI; background service; notification controls; persistence/history; duplex; echo cancellation; AGC; resampling; timing recovery changes; physical performance metrics; authentication; encryption; file-transfer changes и supported-route claim.

## References

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[4] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)
