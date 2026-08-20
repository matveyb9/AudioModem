# ADLP v1: bootstrap container и WAV transport

[English (canonical)](protocol-v1.md) · **Русский перевод**

> **Translation of:** [spec/protocol-v1.md](protocol-v1.md). **Last synced:** 2026-08-20. Английский оригинал является нормативным для совместимости реализации.

**Статус:** Experimental. Этот документ определяет ADLP v1 wire object и детерминированный bootstrap path для automated tests и lossless WAV exchange. Он не является over-the-air acoustic PHY specification; отдельный [экспериментальный carrier Acoustic-1](acoustic-1_RU.md) имеет собственный controlled-test scope.

## Слои

`TransferManifest + payload` кодируются в ADLP wire object. Bootstrap codec отображает объект в mono 48 kHz 16-bit PCM WAV. Отдельный codec `Acoustic-1` также переносит неизменённый wire object и заменяет только symbol mapper, а не ADLP bytes.

## ADLP wire object

Все multi-byte integers — big-endian. Объект оканчивается CRC-32C, вычисленным по всем предыдущим байтам.

| Поле | Размер | Примечание |
| --- | ---: | --- |
| Magic | 4 bytes | ASCII `ADLP` |
| Protocol version | 1 byte | `1` |
| Profile ID | 1 byte | `1` Reliable, `2` Balanced, `3` Fast, `4` Narrowband |
| Object kind | 1 byte | `1` Text, `2` File |
| Session ID | 8 bytes | Opaque value, выбранное отправителем |
| Callsign | 1 + N bytes | UTF-8, N ≤ 32 |
| MIME type | 1 + N bytes | UTF-8, N ≤ 96 |
| File name | 1 + N bytes | UTF-8, N ≤ 160; пустое для text |
| Payload length | 4 bytes | N ≤ 16 MiB |
| Payload | N bytes | Исходные text/file bytes |
| CRC-32C | 4 bytes | Castagnoli checksum |

Позывной является открытой metadata и не является authentication mechanism. Future encryption envelope намеренно находится за пределами этого bootstrap format и потребует отдельного RFC.

## Bootstrap WAV carrier

Encoder записывает canonical RIFF/WAVE, mono, PCM signed 16-bit, 48 kHz. За 64-bit alternating preamble следует sync word `0xD3A5`, 32-bit wire-object length, затем ADLP object. Каждый bit представлен 24 constant samples: positive amplitude для `1`, negative amplitude для `0`. Этот profile намеренно прост для воспроизводимости; это не robust acoustic modem waveform.

## Пресеты

Текущий `profile_id` переносится в manifest и декодируется автоматически. В bootstrap release все presets используют одинаковый symbol mapper, но сохраняют разные identifiers, чтобы UI и future PHY work могли развиваться без изменения контейнера.
