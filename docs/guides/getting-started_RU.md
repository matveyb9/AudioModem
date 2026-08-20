# Быстрый старт: проверка WAV-передачи

[English (canonical)](getting-started.md) · **Русский перевод**

> **Translation of:** [docs/guides/getting-started.md](getting-started.md). **Last synced:** 2026-08-20.

Это руководство проверяет первый реализованный путь AudioModem. Оно не проверяет динамик, микрофон, Bluetooth-устройство или радиостанцию. Вместо этого используется lossless WAV, чтобы неудачный round trip можно было отнести к container или codec, а не к неизвестному live-аудиомаршруту.

## Предварительные требования

Установите стабильный Rust toolchain и клонируйте репозиторий. Native Flutter UI теперь использует тот же Rust core и может локально сохранять/открывать WAV files, но diagnostic CLI остаётся самым прямым воспроизводимым entry point для этого теста. Web build намеренно не открывает native codec.

```bash
git clone https://github.com/matveyb9/AudioModem.git
cd AudioModem
cargo test --workspace
```

## Кодирование текста в WAV

Последний аргумент необязателен, по умолчанию используется `balanced`. Для bootstrap compatibility выберите `reliable`, `balanced`, `fast` или `narrowband`.

```bash
cargo run -p adlp-cli -- encode-text hello.wav N1 "Hello from AudioModem" reliable
```

Команда сериализует ADLP v1 text object и отображает его в mono 48 kHz signed 16-bit PCM WAV. `N1` — callsign, видимый в открытой metadata. Он **не** идентифицирует и не аутентифицирует отправителя.

## Передача файла и декодирование

Скопируйте `hello.wav` на принимающую машину любым обычным файловым каналом и выполните:

```bash
cargo run -p adlp-cli -- decode hello.wav
```

Decoder выводит ADLP version, profile, session value, callsign, sample count и text. Он обязан отклонить malformed bootstrap framing или CRC-32C mismatch до возврата payload.

## Controlled Acoustic-1 WAV experiment

Acoustic-1 — отдельный экспериментальный B-FSK carrier. Он использует другой encoder и decoder, поэтому обе команды должны явно называть carrier. Его framing, bounded synchronisation, Hamming(7,4) layer и limits определены в [Acoustic-1 RFC](../../spec/acoustic-1_RU.md).

```bash
cargo run -p adlp-cli -- encode-acoustic1-text acoustic1.wav N1 "Контролируемый тест" balanced
cargo run -p adlp-cli -- decode-acoustic1 acoustic1.wav
```

Acoustic-1 WAV round trip доказывает только controlled PCM/WAV codec behavior. Он не доказывает speaker-to-microphone synchronisation, tolerance room noise, gain handling, radio compatibility или любой live route.

## Controlled measurement Acoustic-2

Acoustic-2 применяет declared integer-domain transforms к существующему Acoustic-1 WAV, затем сообщает только то, что может наблюдать существующий codec. Optional values ниже — leading silence, gain per mille, noise peak, noise seed и hard-clip threshold.

```bash
cargo run -p adlp-cli -- measure-acoustic1 acoustic1.wav 137 500 200 2885812225 8000
```

Команда выводит accepted/rejected codec result, sample counts, bounded acquisition offset и ADLP profile. Числа воспроизводимы для этого exact WAV и parameter vector; они не являются BER, SNR, range, room-noise, clock-drift или device compatibility metrics. Полные transform order и bounds приведены в [Acoustic-2 contract](../../spec/acoustic-2_RU.md).

## Что доказывает тест — и чего не доказывает

| Тест доказывает | Тест не доказывает |
| --- | --- |
| Реализованный ADLP v1 object переживает один детерминированный WAV encode/decode cycle. | Что waveform пройдёт через speech-band audio, динамик, микрофон, кабель, Bluetooth adapter или радио. |
| Final integrity check обнаруживает intentional corrupted-frame cases из Rust-тестов; Acoustic-1 также имеет bounded noise, framing, FEC и golden-vector regression cases. | Что callsign принадлежит человеку, устройству или ключу. |
| Acoustic-2 transform vector имеет deterministic PCM output и codec-observable acquisition values. | Что synthetic gain/noise/clip/deletion values предсказывают physical audio channel. |
| Тест переносим между Rust development environments. | Что передача зашифрована, конфиденциальна или authenticated. |

## Следующие шаги

Прочитайте [Аудиомаршруты](audio-routes_RU.md), чтобы понять, почему WAV является reference transport и что требуется до статуса supported для live route. Формат объекта описан в [спецификации ADLP v1](../../spec/protocol-v1_RU.md), experimental carrier compatibility — в [Acoustic-1 RFC](../../spec/acoustic-1_RU.md), а controlled measurements — в [Acoustic-2 contract](../../spec/acoustic-2_RU.md).
