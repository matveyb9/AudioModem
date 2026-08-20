# AudioModem

> **Экспериментальный open-source канал передачи данных по аудио.** Сегодня проект передаёт текст через lossless WAV-файлы; в дальнейшем — через динамик, микрофон, аудиокабель, радиотракт и Bluetooth-аудиомаршруты ОС.

[English (canonical)](README.md) · **Русский перевод**

AudioModem отделяет версионированный объект данных от маршрута, который переносит его PCM-сигнал. Один и тот же объект ADLP можно экспортировать в WAV для воспроизводимой передачи, отправить будущим маршрутом «динамик → микрофон», подключить к line-level кабелю или направить через внешнее радиооборудование. Репозиторий содержит Rust protocol/core, Flutter-интерфейс и открытую спецификацию.

> **Статус перевода:** перевод `README.md`; синхронизировано 2026-08-20. Английский оригинал является нормативным для совместимости протокола, release commitments и решений реализации.

## Статус

AudioModem имеет проверенные Rust ADLP/WAV codecs, native Flutter↔Rust bridge и локальный WAV import/export. Доступны два контролируемых WAV carriers: детерминированный bootstrap и экспериментальный Acoustic-1 B-FSK. Проверенный путь выглядит так: text → ADLP v1 object → выбранный WAV carrier → ADLP v1 object → verified text. Live capture/playback, Bluetooth-аудиомаршрутизация, радиоинтерфейсы, шифрование, application-level file payload workflow и release artifacts **не реализованы**. Очерёдность работ приведена в [дорожной карте](docs/roadmap_RU.md).

| Область | Текущий статус | Подробнее |
| --- | --- | --- |
| ADLP v1 container | Реализован и покрыт Rust-тестами | [Протокол](spec/protocol-v1_RU.md) |
| Bootstrap WAV codec | Реализован для детерминированного 48 kHz mono PCM WAV round trip | [Быстрый старт](docs/guides/getting-started_RU.md) |
| Flutter client | Native Rust bridge и локальный WAV import/export; web честно сообщает, что native codec недоступен | [Архитектура bridge](docs/architecture/flutter-rust-bridge_RU.md) |
| Acoustic-1 carrier | Экспериментальный B-FSK controlled PCM/WAV codec с framing, Hamming(7,4), bounded sync и golden vectors; без live-route claim | [Acoustic-1 RFC](spec/acoustic-1_RU.md) |
| Live acoustic modem | Не реализован: нет capture/playback route adapter или device acceptance result | [Аудиомаршруты](docs/guides/audio-routes_RU.md) |
| Шифрование и проверяемая идентичность | Будущая RFC-работа | [Безопасность](SECURITY.md) |

## Быстрый старт: воспроизводимый WAV round trip

Установите стабильный Rust toolchain, клонируйте репозиторий и выполните диагностический CLI из корня workspace.

```bash
cargo run -p adlp-cli -- encode-text hello.wav N1 "Hello from AudioModem" reliable
cargo run -p adlp-cli -- decode hello.wav
```

Команда записывает lossless mono 48 kHz signed 16-bit PCM WAV и затем декодирует тот же объект. Bootstrap symbol mapper намеренно прост и **не** является надёжной схемой модуляции для передачи по воздуху. Гарантии и ограничения описаны в [руководстве быстрого старта](docs/guides/getting-started_RU.md).

Для controlled experiment с отдельным экспериментальным carrier используйте явные Acoustic-1 commands. Успешный WAV round trip доказывает только этот codec contract; он не демонстрирует speaker-to-microphone link.

```bash
cargo run -p adlp-cli -- encode-acoustic1-text acoustic1.wav N1 "Контролируемый тест" balanced
cargo run -p adlp-cli -- decode-acoustic1 acoustic1.wav
```

## Документация

| Английский оригинал | Русский перевод | Назначение |
| --- | --- | --- |
| [Documentation index](docs/README.md) | [Индекс документации](docs/README_RU.md) | Навигация и языковая политика |
| [Quick start](docs/guides/getting-started.md) | [Быстрый старт](docs/guides/getting-started_RU.md) | Воспроизводимый WAV workflow |
| [Audio routes](docs/guides/audio-routes.md) | [Аудиомаршруты](docs/guides/audio-routes_RU.md) | Границы WAV, live PCM, cable, radio и Bluetooth |
| [Protocol v1](spec/protocol-v1.md) | [Протокол v1](spec/protocol-v1_RU.md) | ADLP object и bootstrap WAV carrier |
| [Acoustic-1 RFC](spec/acoustic-1.md) | [Acoustic-1 RFC на русском](spec/acoustic-1_RU.md) | Экспериментальный B-FSK carrier и граница compatibility |
| [Platform support](docs/reference/platform-support.md) | [Поддержка платформ](docs/reference/platform-support_RU.md) | Target runners и feature status |
| [Transmission presets](docs/reference/presets.md) | [Пресеты передачи](docs/reference/presets_RU.md) | Reliable, Balanced, Fast и Narrowband IDs |
| [Troubleshooting](docs/troubleshooting.md) | [Диагностика](docs/troubleshooting_RU.md) | Наблюдаемые ошибки и полезные отчёты |
| [Roadmap](docs/roadmap.md) | [Дорожная карта](docs/roadmap_RU.md) | Проверенная работа и план |

## Участие и безопасность

Перед pull request прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Изменения protocol, DSP и crypto начинаются с RFC-процесса из [GOVERNANCE.md](GOVERNANCE.md). Для private security report используйте [SECURITY.md](SECURITY.md); не публикуйте уязвимость в issue.

## Лицензия

Код распространяется по двойной лицензии **MIT OR Apache-2.0**. Документация распространяется по **CC-BY-4.0**, если не указано иное. См. [LICENSE-MIT](LICENSE-MIT) и [LICENSE-APACHE](LICENSE-APACHE).
