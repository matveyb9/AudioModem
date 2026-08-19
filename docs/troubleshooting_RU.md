# Диагностика

[English (canonical)](troubleshooting.md) · **Русский перевод**

> **Translation of:** [docs/troubleshooting.md](troubleshooting.md). **Last synced:** 2026-08-19.

Эта страница документирует наблюдаемый bootstrap path. Она не предлагает workaround для live capture, Bluetooth или radio, потому что эти routes не реализованы. Полезный report содержит факты, которые может воспроизвести другой contributor.

| Симптом | Первая проверка | Ожидаемый результат |
| --- | --- | --- |
| `cargo run` не находит package | Запустите из корня repository и укажите `-p adlp-cli`. | Cargo находит workspace member. |
| `encode-text` отклоняет profile | Используйте `reliable`, `balanced`, `fast` или `narrowband`. | CLI принимает profile или использует `balanced` по умолчанию. |
| `decode` отклоняет WAV file | Убедитесь, что файл создан bootstrap CLI и не был transcoded. | Decoder принимает canonical mono 48 kHz signed 16-bit PCM WAV с bootstrap signal. |
| Decoded text отсутствует | Сохраните CLI output и file checksum; выполните `cargo test --workspace`. | Decoder не должен печатать payload после failed framing или CRC-32C check. |
| Live route отсутствует в Flutter UI | Проверьте platform support matrix. | Это ожидаемо до реализации Rust bridge и live-audio adapters. |

## Шаблон отчёта

Для device observations используйте device-compatibility issue form. Для codec или CLI failure включите следующую информацию в bug report.

```text
AudioModem revision:
Operating system and version:
Rust version:
Command run:
Selected profile:
Expected result:
Actual result:
Reproduction steps:
WAV SHA-256 (не загружайте private content):
```

## Security-sensitive findings

Не сообщайте о потенциальной уязвимости confidentiality, integrity или authentication в public issue. Следуйте [SECURITY.md](../SECURITY.md). Возможность подделать callsign ожидаема в ADLP v1 и сама по себе не является уязвимостью.
