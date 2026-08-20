# Диагностика

[English (canonical)](troubleshooting.md) · **Русский перевод**

> **Translation of:** [docs/troubleshooting.md](troubleshooting.md). **Last synced:** 2026-08-20.

Эта страница документирует наблюдаемые bootstrap, Acoustic-1 и Acoustic-2 controlled PCM paths. Она не предлагает workaround для live capture, Bluetooth или radio, потому что эти routes не реализованы. Полезный report содержит факты, которые может воспроизвести другой contributor.

| Симптом | Первая проверка | Ожидаемый результат |
| --- | --- | --- |
| `cargo run` не находит package | Запустите из корня repository и укажите `-p adlp-cli`. | Cargo находит workspace member. |
| `encode-text` отклоняет profile | Используйте `reliable`, `balanced`, `fast` или `narrowband`. | CLI принимает profile или использует `balanced` по умолчанию. |
| `decode` отклоняет WAV file | Убедитесь, что файл создан bootstrap CLI и не был transcoded. | Decoder принимает canonical mono 48 kHz signed 16-bit PCM WAV с bootstrap signal. |
| `decode-acoustic1` отклоняет WAV file | Убедитесь, что carrier command соответствует файлу, а файл является canonical 48 kHz PCM. | Decoder принимает только Acoustic-1 framing; bootstrap WAV намеренно отклоняется. |
| `measure-acoustic1` отклоняет transform | Зафиксируйте каждый supplied transform argument и сначала проверьте unmodified file. | Invalid bounds, periodic deletion или failed Acoustic-1 framing возвращают error; payload/measurement не печатается. |
| Decoded text отсутствует | Сохраните CLI output и file checksum; выполните `cargo test --workspace`. | Decoder не должен печатать payload после failed framing или CRC-32C check. |
| Native codec недоступен в web build | Используйте native runner для текущих Rust codec workflows. | Это ожидаемо: web target намеренно не имеет WASM codec. |
| Live route отсутствует в Flutter UI | Проверьте platform support matrix. | Native bridge/local WAV workflow существуют, но live-audio adapters всё ещё не реализованы. |

## Шаблон отчёта

Для device observations используйте device-compatibility issue form. Для codec или CLI failure включите следующую информацию в bug report.

```text
AudioModem revision:
Operating system and version:
Rust version:
Command run:
Selected profile:
Selected carrier:
Acoustic-2 transform arguments, если использовались:
Expected result:
Actual result:
Reproduction steps:
WAV SHA-256 (не загружайте private content):
```

## Security-sensitive findings

Не сообщайте о потенциальной уязвимости confidentiality, integrity или authentication в public issue. Следуйте [SECURITY.md](../SECURITY.md). Возможность подделать callsign ожидаема в ADLP v1 и сама по себе не является уязвимостью.
