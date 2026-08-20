# Исследовательские заметки по constrained live-audio adapter

[English (canonical)](live-audio-adapter-sources.md) · **Русский перевод**

> **Translation of:** [docs/research/live-audio-adapter-sources.md](live-audio-adapter-sources.md). **Last synced:** 2026-08-20.

Первый live-audio milestone должен определить typed application boundary до выбора runtime plugin или заявления route. Contract будет рассматривать permission, session activation, interruption, playback, capture и disposal как отдельно observable states. Он не будет выводить stable sample rate, hardware route, acoustic result или platform support из plugin dependency.

| Источник | Значимое наблюдение | Следствие для RFC |
| --- | --- | --- |
| Flutter cookbook, *Record or stream audio input* | Audio input требует user permission и может требовать platform-specific configuration; capture configuration, streaming, stopping и disposal являются отдельными operations.[1] | Требовать explicit permission и lifecycle outcomes; не выдавать capture bytes, пока platform adapter не существует и не сообщает supported PCM format. |
| Документация `audio_session` | iOS имеет app-wide shared audio session; Android attributes применяются per player/track. Activation может быть denied, а interruption/device events требуют policy.[2] | Сделать session activation, interruption и route-change events explicit; core contract не должен молча владеть platform-session policy. |
| Android audio-focus guidance | Playback должен request focus непосредственно перед use, обрабатывать focus loss и abandon focus после завершения; behavior различается между Android versions и contexts.[3] | Playback — opt-in command, failure которого не начинает output. В v1 не обещается automatic resume или ducking policy. |

## Позиция RFC

Constrained adapter contract поставляется только с unavailable implementation. Он даёт Flutter workbench stable dependency seam и truthful status message, пока отсутствуют device-acceptance reports, single-route platform RFC и hardware evidence. В этом milestone не добавляются recording package, audio-session package или microphone permission.

## Ссылки

[1]: https://docs.flutter.dev/cookbook/audio/record "Record or stream audio input"
[2]: https://pub.dev/packages/audio_session "audio_session package documentation"
[3]: https://developer.android.com/media/optimize/audio-focus "Manage audio focus"
