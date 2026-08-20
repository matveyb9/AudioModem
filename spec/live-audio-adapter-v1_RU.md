# Constrained live-audio adapter v1

[English (canonical)](live-audio-adapter-v1.md) · **Русский перевод**

> **Translation of:** [spec/live-audio-adapter-v1.md](live-audio-adapter-v1.md). **Last synced:** 2026-08-20. Английский оригинал определяет implementation contract.

Этот RFC определяет application boundary будущего live audio route. Он не добавляет capture, playback, microphone permission, audio focus, device enumeration, cable routing, Bluetooth routing, radio support или supported platform. Начальная реализация предоставляет только unavailable adapter, чтобы UI и tests отличали designed interface от работающего route.

## Scope и ограничение первого route

Первый physical route, только после отдельного approval, будет **одним local speaker-to-microphone simplex path** с одним documented platform/device scope. Он может передавать один selected ADLP carrier как raw mono PCM16 frames. Route RFC, platform implementation, complete device-acceptance evidence и target-specific tests должны существовать до включения adapter.

V1 contract не выбирает Flutter recording/playback package. Flutter guidance показывает, что permission, capture configuration, stream control и disposal — отдельные responsibilities, а platform support varies по encoding и target.[1] Session configuration и focus ownership также platform-specific, включая app-wide iOS session behavior и Android per-track attributes.[2] [3]

## Typed contract

Flutter-facing interface имеет три concerns.

| Type | Responsibility | Required invariant |
| --- | --- | --- |
| `PcmStreamFormat` | Описывает будущие raw frames: sample rate, channels и sample format. | V1 принимает только `48,000 Hz`, mono, signed PCM16 little-endian. WAV containers не принимаются. |
| `LiveAudioAvailability` | Сообщает, включён ли concrete adapter и почему нет. | `isAvailable == false` никогда не означает permission, capture, playback или device discovery. |
| `LiveAudioAdapter` | Резервирует lifecycle commands `startPlayback`, `startCapture` и `stop`. | Command может начаться только после проверки format, permission и session/focus activation platform adapter'ом. |

Unavailable adapter обязан возвращать failed future для каждого lifecycle command с той же public reason, что и в `availability`. Он не должен запрашивать permission, инициализировать plugin, обращаться к microphone, перечислять hardware, выдавать captured bytes или воспроизводить audio.

## Lifecycle и state boundary

Contract называет states, но пока не реализует route state machine.

```text
unavailable ──(approved platform adapter)──> idle
idle ──(permission + session/focus granted)──> active playback | active capture
active ──(interrupt/route change/user stop)──> idle
any state ──(dispose)──> disposed
```

Future adapter отвечает за преобразование native permission, audio-session/focus, interruption и route-change signals в truthful failure или stop events. Он не должен автоматически resume после interruption в v1. На Android focus может быть denied или delayed и должен быть обработан до начала output; на iOS audio-session settings shared во всём app, поэтому adapter/plugin ownership должен быть declared до activation.[2] [3]

## Required future acceptance gates

| Gate | Требуется до включения route | Недостаточное evidence |
| --- | --- | --- |
| Contract gate | Этот RFC, typed adapter, unavailable behavior tests и отсутствие hidden plugin initialization. | Dependency в `pubspec.yaml`. |
| Platform gate | Один approved platform implementation с permission/session/focus handling и reproducible native build. | Generic cross-platform interface. |
| Device gate | Reviewed `physical_route` reports по [device-acceptance protocol](../docs/operations/device-acceptance_RU.md), включая fixture hashes, route settings и failures. | Schema-valid template или controlled Acoustic-2 result. |
| Route gate | Target-specific integration tests, documented limits и maintainer approval. | Successful run на undocumented device. |

## Security и privacy

Live routes могут захватывать private ambient audio. Adapter должен быть opt-in, минимизировать retained audio и не сохранять raw frames или callsigns автоматически. Любой device report следует правилам recording availability и privacy из device-acceptance protocol. Encryption остаётся отдельным от route transport и не подразумевается live adapter'ом.

## Non-goals

Этот RFC не предоставляет automatic gain control, echo cancellation, resampling, timing recovery, FEC changes, duplex mode, background execution, Bluetooth/cable/radio routing, device discovery, audio visualization, Web Audio, microphone permission UI, playback, capture или physical interoperability.

## Ссылки

[1]: https://docs.flutter.dev/cookbook/audio/record "Record or stream audio input"
[2]: https://pub.dev/packages/audio_session "audio_session package documentation"
[3]: https://developer.android.com/media/optimize/audio-focus "Manage audio focus"
