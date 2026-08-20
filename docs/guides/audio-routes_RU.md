# Аудиомаршруты и границы транспорта

[English (canonical)](audio-routes.md) · **Русский перевод**

> **Translation of:** [docs/guides/audio-routes.md](audio-routes.md). **Last synced:** 2026-08-20.

Маршрут AudioModem доставляет PCM samples. Он не определяет data object. ADLP object, frame integrity и выбранный profile должны оставаться независимыми от того, сохраняются ли samples, воспроизводятся, записываются или проходят через другое устройство. Это позволяет использовать один data-link layer для delayed file exchange и one-way radio path.

## Матрица маршрутов

| Маршрут | Модель доставки | Bootstrap status | Требование до статуса “supported” |
| --- | --- | --- | --- |
| Lossless WAV | Файл переносит canonical PCM samples. | Реализован для text round trips и явного локального import/export в Flutter workbench. | Наблюдения acoustic interoperability на разных платформах и опубликованная fixture compatibility policy. |
| Controlled Acoustic-1 WAV | Файл переносит B-FSK PCM samples и тот же ADLP v1 wire object. | Экспериментальный: реализованы framing, bounded synchronisation, Hamming(7,4), profile-driven symbol windows и golden vector. | Route adapter плюс declared speaker-to-microphone/device measurements. |
| Динамик → микрофон | Local acoustic simplex path. | Планируется. | Synchronization, level handling, FEC, noisy-room measurements и device tests. |
| Аудиокабель | Line-level PCM path. | Планируется. | Device selection, sample-rate handling, gain guidance и cross-platform tests. |
| OS-managed Bluetooth | Выбранный audio input/output route. | Планируется. | Per-platform permission/routing adapters и device compatibility testing. |
| Радиоинтерфейс | Внешний radio или transceiver audio path. | Планируется. | Narrowband profile, radio-specific framing tests, lawful operating guidance и fixtures. |

## Независимость транспорта

Encoder создаёт ADLP object до выбора physical profile. Затем profile превращает object в PCM signal. Adapter может записать этот поток в WAV, отправить его на playback device или получить от capture device. Receiver выполняет шаги в обратном порядке и не возвращает payload, пока не завершатся object integrity checks.

```text
object → ADLP frame → selected PHY profile → PCM → route
route → PCM → selected PHY profile → ADLP frame → verified object
```

## Локальный WAV file workflow

Текущий Flutter workbench может сохранить проверенную WAV-передачу из памяти через выбранный пользователем save dialog и выбрать один `.wav` файл через локальный open dialog. File adapter владеет только platform dialog и raw bytes. Каждая импортированная последовательность байтов всё равно передаётся в Rust bridge `decodeWav`; UI показывает metadata payload только после успешной проверки framing, manifest и CRC-32C. Отмена диалога не считается ошибкой и не создаёт состояние передачи.

Adapter использует `file_picker`: его документированный API поддерживает custom extension filters, чтение bytes и save-file dialogs на Android, iOS, Linux, macOS, Windows и web.[1] Adapter не утверждает, что файл можно воспроизвести через динамик, захватить с микрофона, направить по Bluetooth или получить через аудиокабель.

## Golden compatibility fixture

`crates/audio-modem-core/tests/fixtures/adlp-v1-text-balanced.wav` — фиксированный canonical fixture для ADLP v1 WAV bootstrap. `crates/audio-modem-core/tests/fixtures/acoustic-1-v1-text-balanced.wav` выполняет ту же роль для экспериментального Acoustic-1 carrier. Их Rust regression tests декодируют fixtures и сравнивают целые byte sequences со свежими deterministic encodings документированных входных objects. Поэтому любое различие байтов является изменением codec, влияющим на compatibility, и должно быть проверено вместе с обновлёнными fixture, hash и protocol rationale.

## Позывные и приватность

Позывной — незашифрованная display metadata в ADLP v1. Он может быть полезен оператору, но не является identity proof. Future key exchange, encryption и signatures должны быть описаны отдельным RFC и не могут подразумеваться из наличия callsign.

## Правило для adapters

Adapter обязан сообщать наблюдаемые route facts — selected device, nominal sample rate, channel count, level или permission failure — не меняя ADLP object. Route diagnostics относятся к app event/reporting layer, а codec остаётся deterministic и independently testable.

## Ссылки

[1]: https://pub.dev/packages/file_picker "Документация пакета file_picker"
