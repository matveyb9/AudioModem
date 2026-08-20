# Пресеты передачи

[English (canonical)](presets.md) · **Русский перевод**

> **Translation of:** [docs/reference/presets.md](presets.md). **Last synced:** 2026-08-20.

Пресет — именованный выбор параметров physical-layer profile. Он выражает user-facing компромисс скорость/надёжность, а `profile_id` остаётся внутри ADLP object. Receiver читает ID из manifest; sender не нуждается в отдельной out-of-band настройке для базового выбора profile.

## Profile identifiers и controlled carrier behavior

| Profile ID | Пресет | Bootstrap carrier | Экспериментальный Acoustic-1 PCM/WAV carrier |
| ---: | --- | --- | --- |
| `1` | Reliable | Shared deterministic symbol mapper. | 480 samples/symbol, nominal 100 baud. |
| `2` | Balanced | Shared deterministic symbol mapper. | 240 samples/symbol, nominal 200 baud. |
| `3` | Fast | Shared deterministic symbol mapper. | 144 samples/symbol, nominal 333.3 baud. |
| `4` | Narrowband | Shared deterministic symbol mapper. | 480 samples/symbol, nominal 100 baud; это не radio narrowband compliance claim. |

## Текущие ограничения

ID являются настоящими protocol fields. Детерминированный bootstrap carrier всё ещё не меняет modulation, bit rate, coding или error correction по profile. Отдельный экспериментальный Acoustic-1 carrier меняет symbol window, как показано выше, и применяет фиксированный Hamming(7,4) FEC к своей длине и ADLP wire bytes. Эти controlled PCM/WAV facts не устанавливают live acoustic reliability ranking для “Reliable”, “Balanced” или “Fast”.

## Future profile contract

До того как profile станет selectable для live audio, его specification должна определить occupied band, nominal sample rate, framing, synchronization, coding/FEC behavior, preamble, acceptance metrics и golden test vectors. Также нужны route adapter и declared device measurements. UI label вроде “Fast” не является достаточным compatibility definition.
