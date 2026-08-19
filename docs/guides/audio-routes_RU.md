# Аудиомаршруты и границы транспорта

[English (canonical)](audio-routes.md) · **Русский перевод**

> **Translation of:** [docs/guides/audio-routes.md](audio-routes.md). **Last synced:** 2026-08-19.

Маршрут AudioModem доставляет PCM samples. Он не определяет data object. ADLP object, frame integrity и выбранный profile должны оставаться независимыми от того, сохраняются ли samples, воспроизводятся, записываются или проходят через другое устройство. Это позволяет использовать один data-link layer для delayed file exchange и one-way radio path.

## Матрица маршрутов

| Маршрут | Модель доставки | Bootstrap status | Требование до статуса “supported” |
| --- | --- | --- | --- |
| Lossless WAV | Файл переносит canonical PCM samples. | Реализован для text round trips. | Golden fixtures, documented CLI behavior и CI verification. |
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

## Позывные и приватность

Позывной — незашифрованная display metadata в ADLP v1. Он может быть полезен оператору, но не является identity proof. Future key exchange, encryption и signatures должны быть описаны отдельным RFC и не могут подразумеваться из наличия callsign.

## Правило для adapters

Adapter обязан сообщать наблюдаемые route facts — selected device, nominal sample rate, channel count, level или permission failure — не меняя ADLP object. Route diagnostics относятся к app event/reporting layer, а codec остаётся deterministic и independently testable.
