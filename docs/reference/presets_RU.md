# Пресеты передачи

[English (canonical)](presets.md) · **Русский перевод**

> **Translation of:** [docs/reference/presets.md](presets.md). **Last synced:** 2026-08-19.

Пресет — именованный выбор параметров physical-layer profile. Он выражает user-facing компромисс скорость/надёжность, а `profile_id` остаётся внутри ADLP object. Receiver читает ID из manifest; sender не нуждается в отдельной out-of-band настройке для базового выбора profile.

## Зарезервированные profile identifiers

| Profile ID | Пресет | Предполагаемые условия маршрута | Bootstrap implementation |
| ---: | --- | --- | --- |
| `1` | Reliable | Шумный acoustic route, неизвестный gain или radio interface | Использует shared bootstrap symbol mapper. |
| `2` | Balanced | Обычный speaker/microphone или cable route | Использует shared bootstrap symbol mapper. |
| `3` | Fast | Чистый line route или reproducible WAV path | Использует shared bootstrap symbol mapper. |
| `4` | Narrowband | Будущий radio-oriented profile | Использует shared bootstrap symbol mapper. |

## Текущее ограничение

ID являются настоящими protocol fields, но в bootstrap release пока не меняют modulation, bit rate, coding или error correction. Они зарезервированы заранее, чтобы future Acoustic-1 profile work мог добавить отдельное PHY behavior без изменения ADLP wire object или user mental model.

## Future profile contract

До того как profile станет selectable для live audio, его specification должна определить occupied band, nominal sample rate, framing, synchronization, coding/FEC behavior, preamble, acceptance metrics и golden test vectors. UI label вроде “Fast” не является достаточным compatibility definition.
