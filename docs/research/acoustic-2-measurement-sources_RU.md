# Исследовательские заметки по измерениям Acoustic-2

[English (canonical)](acoustic-2-measurement-sources.md) · **Русский перевод**

> **Translation of:** [docs/research/acoustic-2-measurement-sources.md](acoustic-2-measurement-sources.md). **Last synced:** 2026-08-20.

Acoustic-2 — repository-only controlled PCM measurement milestone. Он не представляет микрофон, динамик, помещение, operating system audio stack, radio или Bluetooth path. Его цель — сделать эффекты declared sample-domain transforms воспроизводимыми до начала отдельной device-acceptance работы.

| Источник | Значимое наблюдение | Следствие для этого milestone |
| --- | --- | --- |
| Sanchez, *FSK Demodulation and Bit String Extraction* | Timing recovery выравнивает sampling instants с symbol boundaries, уменьшает ошибки при timing offset/jitter и добавляет complexity.[1] | Измерять acquisition offset и предоставлять deterministic bounded offset transform; не заявлять general timing-recovery loop. |
| NCC Group, *Developing an FSK receiver step-by-step* | Preamble отмечает начало data и помогает synchronise receiver; development receiver выигрывает от recorded signals, filtering и explicit clock-recovery stages.[2] | Сохранять preamble acquisition inspectable и показывать measurement results для известного WAV input. |
| Chaudhari, *FSK Demodulation in GNU Radio* | FSK timing synchronization требует receiver strategy, соответствующей actual waveform и operating conditions; generic timing blocks не являются universal production solution.[3] | Рассматривать controlled acquisition как experiment с declared bounds, а не как device interoperability evidence. |

## Граница measurement

Первый harness может применять deterministic leading silence, gain scaling, hard clipping, integer-domain additive noise и fixed sample drops. Он сообщает, принят ли generated WAV, и codec-observable values, такие как selected acquisition offset и samples consumed. Он не создаёт BER, SNR, range, room-noise, clock-drift или device-compatibility claims из synthetic data.

## Ссылки

[1]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[2]: https://nccgroup.github.io/RFTM/fsk_receiver.html "RF Testing Methodology: Developing an FSK receiver step-by-step"
[3]: https://wirelesspi.com/fsk-demodulation-in-gnu-radio/ "FSK Demodulation in GNU Radio"
