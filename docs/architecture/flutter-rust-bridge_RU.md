# Flutter ↔ Rust WAV bridge

[English (canonical)](flutter-rust-bridge.md) · **Русский перевод**

> **Translation of:** [docs/architecture/flutter-rust-bridge.md](flutter-rust-bridge.md). **Last synced:** 2026-08-19.

Первый native bridge открывает Flutter доступ к существующей Rust-реализации ADLP и WAV bootstrap. Он не добавляет audio capture, playback, Bluetooth, выбранные пользователем файлы, background transmission или encryption. Его цель — сделать один реальный app-to-core round trip наблюдаемым и тестируемым без дублирования protocol или codec logic в Dart.

## Граница

```text
Flutter workbench → generated Dart API → audio_modem_bridge → audio-modem-core + adlp-protocol
```

Bridge crate — тонкий native facade. `adlp-protocol` остаётся ответственным за versioned object и CRC-32C. `audio-modem-core` отвечает за deterministic PCM/WAV encoding и decoding. Generated code — только glue и не должен содержать protocol decisions.

## Публичный контракт

| Операция | Вход | Выход | Поведение при ошибке |
| --- | --- | --- | --- |
| `encodeTextToWav` | Положительный `sessionId`, callsign, UTF-8 text, profile | Canonical 48 kHz mono 16-bit WAV bytes и transfer metadata | Typed Rust error становится Dart exception; partial WAV не возвращается. |
| `decodeWav` | WAV bytes из памяти | Verified text metadata, UTF-8 payload, sample rate и consumed samples | Framing, manifest или CRC-32C failure становится exception; payload не возвращается. |

В этом первом срезе Flutter app выбирает session value. Экран использует positive timestamp-derived value только как local transfer metadata; это не timestamp claim, identity claim или cryptographic nonce.

## Profiles и limits

Bridge принимает `reliable`, `balanced`, `fast` и `narrowband`, напрямую соответствующие ADLP profile IDs 1–4. В bootstrap codec эти IDs пока не меняют PCM modulation или error correction. Native facade отклоняет text длиннее **8 KiB** до WAV allocation. Этот более низкий application limit защищает mobile или desktop UI от случайного создания непрактично больших bootstrap WAV buffers, пока общий protocol limit остаётся больше для future profiles.

## Trust boundary

Позывной — открытая display metadata. Bridge не обещает authentication, confidentiality или identity association. Key exchange, encrypted payloads и signature verification относятся к отдельному reviewed future API и RFC.

## Политика generated code

`flutter_rust_bridge` generated source коммитится, чтобы fresh clone мог собираться без local code generation. Репозиторий также хранит generator configuration и regeneration command. Hand-written Flutter code может вызывать generated API methods, но не должен редактировать generated files.
