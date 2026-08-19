# Быстрый старт: проверка WAV-передачи

[English (canonical)](getting-started.md) · **Русский перевод**

> **Translation of:** [docs/guides/getting-started.md](getting-started.md). **Last synced:** 2026-08-19.

Это руководство проверяет первый реализованный путь AudioModem. Оно не проверяет динамик, микрофон, Bluetooth-устройство или радиостанцию. Вместо этого используется lossless WAV, чтобы неудачный round trip можно было отнести к container или codec, а не к неизвестному live-аудиомаршруту.

## Предварительные требования

Установите стабильный Rust toolchain и клонируйте репозиторий. Текущий Flutter UI пока не соединён с Rust core, поэтому диагностический CLI — поддерживаемая точка входа для этого теста.

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

## Что доказывает тест — и чего не доказывает

| Тест доказывает | Тест не доказывает |
| --- | --- |
| Реализованный ADLP v1 object переживает один детерминированный WAV encode/decode cycle. | Что waveform пройдёт через speech-band audio, динамик, микрофон, кабель, Bluetooth adapter или радио. |
| Final integrity check обнаруживает intentional corrupted-frame cases из Rust-тестов. | Что callsign принадлежит человеку, устройству или ключу. |
| Тест переносим между Rust development environments. | Что передача зашифрована, конфиденциальна или authenticated. |

## Следующие шаги

Прочитайте [Аудиомаршруты](audio-routes_RU.md), чтобы понять, почему WAV является reference transport и что требуется до статуса supported для live route. Формат объекта описан в [спецификации ADLP v1](../../spec/protocol-v1_RU.md).
