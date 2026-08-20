# Flutter ↔ Rust WAV bridge

[English (canonical)](flutter-rust-bridge.md) · **Русский перевод**

> **Translation of:** [docs/architecture/flutter-rust-bridge.md](flutter-rust-bridge.md). **Last synced:** 2026-08-20.

Native bridge открывает Flutter доступ к Rust ADLP и двум controlled WAV codecs: детерминированному bootstrap и экспериментальному Acoustic-1. В app есть отдельный local file adapter для выбора и сохранения WAV bytes, тогда как сам bridge всё ещё не добавляет audio capture, playback, Bluetooth, background transmission или encryption. Его цель — сделать один реальный app-to-core round trip наблюдаемым и тестируемым без дублирования protocol или codec logic в Dart.

## Граница

```text
Flutter workbench → generated Dart API → audio_modem_bridge → audio-modem-core + adlp-protocol
```

Bridge crate — тонкий native facade. `adlp-protocol` остаётся ответственным за versioned object и CRC-32C. `audio-modem-core` отвечает за deterministic PCM/WAV encoding и decoding. Generated code — только glue и не должен содержать protocol decisions.

## Публичный контракт

| Операция | Вход | Выход | Поведение при ошибке |
| --- | --- | --- | --- |
| `encodeTextToWav` | Положительный `sessionId`, callsign, UTF-8 text, profile и явный carrier (`bootstrap` или `acoustic1`) | Canonical 48 kHz mono 16-bit WAV bytes и transfer metadata | Typed Rust error становится Dart exception; partial WAV не возвращается. |
| `decodeWav` | WAV bytes из памяти и явный carrier | Verified text metadata, UTF-8 payload, sample rate и consumed samples | Wrong-carrier, framing, manifest или CRC-32C failure становится exception; payload не возвращается. |

В этом первом срезе Flutter app выбирает session value. Экран использует positive timestamp-derived value только как local transfer metadata; это не timestamp claim, identity claim или cryptographic nonce.

## Граница file adapter

`PlatformWavFileAdapter` открывает локальные platform dialogs и возвращает opaque WAV bytes или передаёт проверенный in-memory buffer на сохранение. Он не анализирует waveform, не принимает решение о protocol validity и не читает payload. Flutter workbench передаёт все выбранные bytes в `decodeWav`; при failed decode полученный object не сохраняется. Это оставляет user filesystem interaction за пределами deterministic protocol и codec boundary.

## Carriers, profiles и limits

Bridge принимает carriers `bootstrap` и `acoustic1`. Bootstrap сохраняет один deterministic symbol mapper для каждого profile. Acoustic-1 использует отдельный B-FSK mapper с profile-dependent symbol windows, Hamming(7,4), bounded frame acquisition и лимитом 256 bytes для ADLP wire object; точный compatibility contract указан в [Acoustic-1 RFC](../../spec/acoustic-1_RU.md). UI хранит carrier selection с явным experimental notice и использует тот же выбор для import, export и verification.

Bridge принимает `reliable`, `balanced`, `fast` и `narrowband`, напрямую соответствующие ADLP profile IDs 1–4. Native facade отклоняет text длиннее **8 KiB** до WAV allocation. Этот более низкий application limit защищает mobile или desktop UI от случайного создания непрактично больших buffers, пока общий protocol limit остаётся больше для future profiles.

## Trust boundary

Позывной — открытая display metadata. Bridge не обещает authentication, confidentiality или identity association. Key exchange, encrypted payloads и signature verification относятся к отдельному reviewed future API и RFC.

## Политика generated code

`flutter_rust_bridge` generated source коммитится, чтобы fresh clone мог собираться без local code generation. Репозиторий также хранит generator configuration и regeneration command. Hand-written Flutter code может вызывать generated API methods, но не должен редактировать generated files.
