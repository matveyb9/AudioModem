# Исследовательские заметки по Acoustic-1 PHY

[English (canonical)](acoustic-1-phy-sources.md) · **Русский перевод**

> **Перевод:** [docs/research/acoustic-1-phy-sources.md](acoustic-1-phy-sources.md). **Последняя синхронизация:** 2026-08-20.

Первый профиль Acoustic-1 использует binary FSK как намеренно небольшой и проверяемый baseline. Это решение дизайна репозитория, а не заявление acoustic interoperability. Необходимым будущим acceptance evidence остаются speaker-to-microphone measurements на объявленных device classes.

| Источник | Значимое наблюдение | Следствие для дизайна Acoustic-1 |
| --- | --- | --- |
| Tiny Tapeout FSK modem | Reference design использует framing `preamble → sync → payload → CRC`, одну frequency для каждого binary state, затем сравнивает два parallel Goertzel filters до integrity validation.[1] | Сохранять versioned framing sequence, distinctive synchronisation word и explicit final integrity validation. |
| Sanchez, *FSK Demodulation and Bit String Extraction* | FSK отображает binary states в discrete mark/space frequencies; non-coherent demodulation не требует carrier-phase synchronisation, а thresholding различает recovered symbols.[2] | Использовать comparison энергии в fixed symbol window вместо phase-coherent recovery в первом codec. |
| liquid-dsp FEC documentation | Hamming block codes используют parity bits для исправления одной bit error в block; дополнительный parity bit добавляет limited error detection при сохранении one-bit correction.[3] | Использовать explicit Hamming(7,4) codewords только как inspectable первый FEC layer и сохранить ADLP CRC-32C как final object-level integrity validation. |

Документированный hardware modem прямо предупреждает, что free-running symbol blocks требуют phase alignment около symbol boundaries.[1] Поэтому Acoustic-1 фиксирует timing assumption и проверяет receiver на bounded leading-sample offsets. Production receiver позднее потребует более robust timing-recovery mechanism; это вне первой реализации.

## Ссылки

[1]: https://tinytapeout.com/chips/ttgf26a/tt_um_hydrocomms "FSK Modem — Tiny Tapeout"
[2]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[3]: https://liquidsdr.org/doc/fec/ "Документация liquid-dsp по forward error-correction"
