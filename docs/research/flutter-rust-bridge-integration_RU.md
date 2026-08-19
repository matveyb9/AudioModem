# Заметка об интеграции Flutter Rust Bridge

[English (canonical)](flutter-rust-bridge-integration.md) · **Русский перевод**

> **Перевод:** [docs/research/flutter-rust-bridge-integration.md](flutter-rust-bridge-integration.md). **Последняя синхронизация:** 2026-08-19.

AudioModem использует `flutter_rust_bridge` v2 для первого Flutter-to-Rust WAV bootstrap среза. Официальное quickstart-руководство описывает модель как обычное Flutter-приложение, Rust crate и generated glue, а также требует повторно генерировать bridge-код при изменении Rust API.[1] Поэтому локальная реализация хранит hand-written Rust API в `apps/audio_modem/rust/src/api/`, generated Rust glue в `src/frb_generated.rs` и generated Dart glue в `lib/src/rust/`.

Официальная документация crate описывает атрибут `frb` и runtime helpers; для первого API, имеющего синхронную форму, проект использует обычные public Rust functions и generated bindings.[2] Generated facade вызывает уже существующие crates `audio-modem-core` и `adlp-protocol`, а не реализует wire- или WAV-логику повторно.

## Повторная генерация

```bash
export PATH="/home/ubuntu/.local/flutter/bin:$HOME/.cargo/bin:$PATH"
cd apps/audio_modem/rust
flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
```

## Ссылки

[1]: https://cjycode.com/flutter_rust_bridge/quickstart "Flutter Rust Bridge v2 Quickstart"
[2]: https://docs.rs/flutter_rust_bridge/latest/flutter_rust_bridge/ "Документация crate flutter_rust_bridge"
