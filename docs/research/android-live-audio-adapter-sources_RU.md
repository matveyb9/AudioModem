# Research note: Android live-audio adapter

[English (canonical)](android-live-audio-adapter-sources.md) · **Русский перевод**

> **Translation of:** [docs/research/android-live-audio-adapter-sources.md](android-live-audio-adapter-sources.md). **Last synced:** 2026-08-21.

**Статус:** Informative research для experimental route RFC. Это не compatibility claim.

## Решение

Первой platform-specific целью дизайна live audio выбран **Android foreground playback и capture**. Он соответствует существующему Flutter shell и позволяет проверить mobile route с permission, не расширяя работу до Linux session-manager policy. Цель намеренно уже, чем «Android support»: она фиксирует adapter contract и route-specific evidence method, а не general device matrix.

| Фактор | Android first target | Linux desktop отложен |
| --- | --- | --- |
| Platform surface | `AudioRecord` pulls capture frames, а `AudioTrack` pushes PCM playback frames. [1] [2] | PipeWire использует devices, nodes, ports, links и session manager, который их конфигурирует и re-links. [5] [6] |
| Граница user consent | `RECORD_AUDIO` — runtime permission; его следует запрашивать в контексте действия, которому он нужен. [1] [3] | Device enablement, profiles, routes и access policy зависят от distribution/session-manager. [6] |
| Playback lifecycle | App получает audio focus непосредственно перед playback, реагирует на focus loss и abandon focus после конца playback. Android 15 добавляет условие foreground/top-app для запроса focus. [4] | Dynamic sink/source changes и links управляются PipeWire и session manager. [5] [6] |
| First acceptance scope | Foreground, user-initiated, default-route experiment с explicit device observations. | Later route RFC должен выбрать backend, session-manager assumptions и reproducible Linux environment. |

## Ограничения, переносимые в RFC

`AudioRecord` требует `RECORD_AUDIO`, записывает посредством application reads и сообщает initialization/operation errors. Его buffer должен считываться до overruns. [1] Поэтому Android adapter создаёт capture только после foreground user action и granted permission, отклоняет uninitialized record, показывает read errors, детерминированно stop/release и не хранит raw microphone PCM после active attempt.

`AudioTrack` принимает PCM через application writes и поддерживает streaming mode. [2] Adapter записывает существующий Rust-produced PCM bounded chunks, детерминированно stop/release и сообщает write или initialization failure вместо заявления о completed transmission. Он запрашивает focus непосредственно перед user-initiated playback и прекращает playback при permanent или transient focus loss; delayed focus — waiting state, но не разрешение начать. [4]

Существующий `PcmStreamFormat.audioModemV1` остаётся application intent: **48 kHz, mono, signed PCM16 little-endian**. Android documentation не гарантирует, что requested 48 kHz capture configuration доступен на каждом device, либо что actual route останется неизменным. Adapter обязан проверить created format/routed device и перейти в rejected или route-changed diagnostic state, если v1 format не сохраняется. `setPreferredDevice()` — только preference, поэтому first implementation не заявляет cable, Bluetooth, headset или radio routing. [1] [2]

Первый adapter не запускает foreground service, не работает в background, не пишет continuously, не auto-resume после interruption, не выбирает Bluetooth route, не выполняет duplex echo cancellation и не заявляет speaker-to-microphone delivery. Android permission guidance требует graceful degradation после denial или revocation; WAV workflow остаётся доступным в этих состояниях. [3]

## Источники

[1] [Android Developers: `AudioRecord` API reference](https://developer.android.com/reference/android/media/AudioRecord)

[2] [Android Developers: `AudioTrack` API reference](https://developer.android.com/reference/android/media/AudioTrack)

[3] [Android Developers: Request runtime permissions](https://developer.android.com/training/permissions/requesting)

[4] [Android Developers: Manage audio focus](https://developer.android.com/media/optimize/audio-focus)

[5] [PipeWire: Overview](https://docs.pipewire.org/devel/page_overview.html)

[6] [WirePlumber: Understanding session management](https://pipewire.pages.freedesktop.org/wireplumber/design/understanding_session_management.html)
