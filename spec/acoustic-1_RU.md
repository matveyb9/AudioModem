# Acoustic-1: экспериментальный audio PHY

[English (canonical)](acoustic-1.md) · **Русский перевод**

> **Перевод:** [spec/acoustic-1.md](acoustic-1.md). **Последняя синхронизация:** 2026-08-20.

Acoustic-1 — первый физический профиль AudioModem для контролируемых PCM/WAV экспериментов. Он переносит неизменённый ADLP v1 wire object и не является заявлением совместимости speaker-to-microphone, radio, Bluetooth или разных устройств. Детерминированный bootstrap carrier остаётся reference transport для lossless tests; Acoustic-1 — отдельный carrier с явным framing и ограниченной error tolerance.

## Scope и compatibility

| Элемент | Правило Acoustic-1 |
| --- | --- |
| Вход и final integrity | ADLP v1 wire object вместе с его существующим CRC-32C. |
| Shape samples | Canonical RIFF/WAVE, mono, signed 16-bit PCM, 48 kHz. |
| Modulation | Binary FSK: один mark tone для `1`, один space tone для `0`. |
| FEC | Hamming(7,4) для length и wire-object nibbles. |
| Лимит объекта | Не более 256 encoded ADLP wire bytes в одном frame. |
| Версия carrier | Acoustic-1 выбирается codec API и не изменяет ADLP v1 version byte. |

Binary FSK с preamble, sync word, payload и final integrity check соответствует структуре практических modem designs.[1] Acoustic-1 использует non-coherent comparison энергии двух tones вместо carrier-phase recovery, что соответствует различию coherent и non-coherent FSK detection.[2]

> **Правило compatibility:** Decoder НЕ ДОЛЖЕН возвращать полученный object, пока не пройдут Hamming decoding, frame bounds, ADLP decoding и ADLP CRC-32C validation.

## Параметры сигнала

Encoder сбрасывает phase на границе каждого symbol. Samples используют integer sine table из 48 значений с amplitude `12,000`, исключая floating-point зависимость encoded golden vectors. Mark использует 1,000 Hz, space — 2,000 Hz; обе частоты являются integer harmonics sample rate 48 kHz.

| ADLP profile | Samples на symbol | Nominal symbol rate | Предполагаемый trade-off |
| --- | ---: | ---: | --- |
| `reliable` | 480 | 100 baud | Больше energy на bit. |
| `balanced` | 240 | 200 baud | Default profile для controlled tests. |
| `fast` | 144 | 333.3 baud | Более короткое symbol window и ожидаемо меньший noise margin. |
| `narrowband` | 480 | 100 baud | Консервативный profile identifier; это **не** заявление radio narrowband compliance. |

Profile передаётся внутри ADLP manifest. Decoder перебирает фиксированные Acoustic-1 profile configurations и ОБЯЗАН отклонить frame, если recovered manifest profile не совпадает с configuration, которым он был декодирован.

## Frame layout

Каждое поле передаётся most-significant bit first. `wire_length` и ADLP wire object защищаются FEC; preamble и sync передаются raw symbols, чтобы receiver получил alignment до FEC.

| Поле | Symbols | Encoding |
| --- | ---: | --- |
| Preamble | 64 | Alternating `1, 0, 1, 0, …`, начинается с `1`. |
| Sync | 16 | Raw `0xD391`. |
| Wire length | 56 | Четыре big-endian bytes длины; каждый 4-bit nibble становится Hamming(7,4) codeword. |
| ADLP wire object | `14 × N` | Каждый byte разбивается на два nibbles; каждый становится Hamming(7,4) codeword. |

Лимит object предотвращает unbounded WAV allocation. При 200 baud FEC payload rate составляет примерно 14.3 encoded wire bytes в секунду без учёта preamble и sync; большие файлы потребуют будущего packetisation design.

## Hamming(7,4) mapping

Acoustic-1 использует positions `1..7` в порядке `p1, p2, d3, p4, d2, d1, d0`. Для nibble `d3 d2 d1 d0` parity является even и вычисляется так:

```text
p1 = d3 XOR d2 XOR d0
p2 = d3 XOR d1 XOR d0
p4 = d2 XOR d1 XOR d0
```

Decoder получает three-bit syndrome и переворачивает indexed position, когда syndrome находится в `1..7`. Hamming block codes исправляют одну bit error в codeword; они не заменяют end-to-end integrity, которым остаётся ADLP CRC-32C.[3] Two-bit corruption может быть неправильно «исправлен», поэтому failed ADLP CRC означает failed frame и не должен возвращать payload.

## Алгоритм receiver

Receiver разбирает canonical 48 kHz PCM WAV и оценивает каждую объявленную profile configuration. Он сканирует только первые 480 PCM samples в поиске frame start: это явно поддерживает bounded leading-silence/timing offset, а не arbitrary timing recovery. Для каждого candidate symbol window он вычисляет in-phase и quadrature correlation energy с fixed mark и space references, затем выбирает большую. Candidate успешен только при совпадении preamble/sync, FEC length не более 256 bytes, ADLP object validates и его manifest profile совпадает с test configuration.

Это ограниченное правило synchronisation выбрано намеренно. Документированный FSK implementation предупреждает, что free-running blocks требуют близкого совпадения с symbol boundaries.[1] Future Acoustic revisions должны добавить timing recovery, level estimation, band-pass filtering, interleaving и device measurements до любого заявления о live-route support.

## Обязательные regression evidence

Implementation обязана иметь deterministic tests для всех четырёх ADLP profile identifiers, leading-silence offset не более 480 samples, одной исправленной Hamming codeword error, invalid double-corruption rejection через ADLP integrity и bounded additive sample noise. Acoustic-1 golden fixture должен декодироваться и пересоздаваться byte-for-byte из документированного ADLP object.

## Non-goals

Acoustic-1 не предоставляет encryption, authentication, replay protection, packet segmentation, ARQ, live playback/capture, AGC, echo cancellation, Bluetooth routing, radio compliance или guarantee успешной межустройственной acoustic передачи.

## Ссылки

[1]: https://tinytapeout.com/chips/ttgf26a/tt_um_hydrocomms "FSK Modem — Tiny Tapeout"
[2]: https://arxiv.org/html/2402.17777v1 "FSK Demodulation and Bit String Extraction: A Python-Centric Approach in SDR Systems"
[3]: https://liquidsdr.org/doc/fec/ "Документация liquid-dsp по forward error-correction"
