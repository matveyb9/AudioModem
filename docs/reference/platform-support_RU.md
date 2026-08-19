# Поддержка платформ

[English (canonical)](platform-support.md) · **Русский перевод**

> **Translation of:** [docs/reference/platform-support.md](platform-support.md). **Last synced:** 2026-08-19.

AudioModem хранит Flutter runners для Android, iOS, Windows, macOS, Linux и Web в одном application directory. Rust workspace предоставляет container и WAV bootstrap codec. Эта структура — implementation target, а не утверждение, что каждая платформа уже поддерживает каждый route.

## Матрица статуса

| Платформа | Flutter runner | Rust/WAV integration | Live audio | Примечание |
| --- | --- | --- | --- | --- |
| Android | Scaffolded | Не подключён | Планируется | Требуются microphone permission и platform route adapter. |
| iOS | Scaffolded | Не подключён | Планируется | Требуются microphone permission и platform route adapter. |
| Windows | Scaffolded | Не подключён | Планируется | Требуются native device enumeration и routing tests. |
| macOS | Scaffolded | Не подключён | Планируется | Требуются native device enumeration и routing tests. |
| Linux | Scaffolded | Не подключён | Планируется | Требуются backend selection и desktop audio tests. |
| Web | Scaffolded | Не подключён | Исследование | Требуются WASM codec integration и browser Web Audio constraints. |

## Интерпретация

“Scaffolded” означает, что Flutter project содержит platform runner и UI можно собрать для данного target. Это **не** означает, что доступны Rust codec, local file handling, microphone permission, playback, Bluetooth routing или acoustic transmission. Строка станет “supported” только после reproducible build, automated checks, documented compatibility note и route-specific acceptance test.

## Compatibility reports

При создании device-compatibility issue приложите app/revision, operating system и version, device class, selected route, nominal sample rate, selected profile, expected behavior и минимальный WAV fixture, если он релевантен. Не добавляйте private audio recording или personal data.
