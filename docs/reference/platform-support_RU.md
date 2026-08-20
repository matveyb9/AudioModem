# Поддержка платформ

[English (canonical)](platform-support.md) · **Русский перевод**

> **Translation of:** [docs/reference/platform-support.md](platform-support.md). **Last synced:** 2026-08-21.

AudioModem хранит Flutter runners для Android, iOS, Windows, macOS, Linux и Web в одном application directory. Rust workspace предоставляет container и WAV bootstrap codec. Эта структура — implementation target, а не утверждение, что каждая платформа уже поддерживает каждый route.

## Матрица статуса

| Платформа | Flutter runner | Rust/WAV integration | Локальный WAV workflow | Live audio | Примечание |
| --- | --- | --- | --- | --- | --- |
| Android | Scaffolded | Bridge source integrated; target build/run не проверен | Source implementation; target dialog не проверен | Draft experimental design | Существуют [foreground adapter RFC](../../spec/android-live-audio-adapter-v1_RU.md) и validator extension; target build, permission behavior, adapter и route evidence остаются непроверенными. |
| iOS | Scaffolded | Bridge source integrated; target build/run не проверен | Source implementation; target dialog не проверен | Планируется | Нужны target build, permission и route-adapter acceptance tests. |
| Windows | Scaffolded | Bridge source integrated; target build/run не проверен | Source implementation; target dialog не проверен | Планируется | Нужны native device enumeration и routing tests. |
| macOS | Scaffolded | Bridge source integrated; target build/run не проверен | Source implementation; target dialog не проверен | Планируется | Нужны native device enumeration и routing tests. |
| Linux | Debug bundle проверен | Native Cargokit/Rust bridge build проверен | Source implementation; dialog interaction не acceptance-tested | Планируется | Нужны backend selection, runtime dialog и desktop audio tests. |
| Web | Release build проверен | Unavailable by design: нет WASM codec | Picker UI может собраться; native Rust decode недоступен | Исследование | Нужны WASM codec integration и browser Web Audio constraints. |

## Интерпретация

“Scaffolded” означает, что Flutter project содержит platform runner. “Bridge source integrated” означает, что общий Flutter/Rust source содержит bridge и file workflow; это не target runtime claim. Linux — единственный native target с verified debug bundle в этом репозитории. Ни одна строка не означает microphone permission, playback, Bluetooth routing, device compatibility или acoustic transmission. Route получает статус “supported” только после reproducible build, automated checks, documented compatibility note и route-specific acceptance test.

## Compatibility reports

При создании device-compatibility issue приложите app/revision, operating system и version, device class, selected route, nominal sample rate, selected profile, expected behavior и минимальный WAV fixture, если он релевантен. Не добавляйте private audio recording или personal data.
