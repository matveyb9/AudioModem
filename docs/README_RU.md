# Документация AudioModem

[English (canonical)](README.md) · **Русский перевод**

Этот каталог содержит читаемую техническую документацию AudioModem. Английские файлы являются каноническими. Русские переводы используют суффикс `_RU.md`, ссылаются на английский оригинал и носят информативный характер, пока RFC явно не установит иное.

> **Translation of:** [docs/README.md](README.md). **Last synced:** 2026-08-21.

| Раздел | Английский оригинал | Русский перевод | Область |
| --- | --- | --- | --- |
| Guides | [Quick start](guides/getting-started.md) | [Быстрый старт](guides/getting-started_RU.md) | Проверенные bootstrap и controlled Acoustic-1 WAV workflows |
| Guides | [Audio routes](guides/audio-routes.md) | [Аудиомаршруты](guides/audio-routes_RU.md) | Маршруты доставки и границы scope |
| Reference | [Platform support](reference/platform-support.md) | [Поддержка платформ](reference/platform-support_RU.md) | Runners и supported features |
| Reference | [Transmission presets](reference/presets.md) | [Пресеты передачи](reference/presets_RU.md) | Profile identifiers и назначение |
| Operations | [Troubleshooting](troubleshooting.md) | [Диагностика](troubleshooting_RU.md) | Воспроизводимые наблюдения и отчёты |
| Operations | [Device acceptance](operations/device-acceptance.md) | [Приёмка устройств](operations/device-acceptance_RU.md) | Evidence contract и decision gates для будущих live routes |
| Project | [Roadmap](roadmap.md) | [Дорожная карта](roadmap_RU.md) | Проверенная работа и ближайшие milestones |
| Project | [Implementation plan](implementation-plan.md) | [План реализации](implementation-plan_RU.md) | Test-gated порядок от core contracts через Flutter shell к route evidence |
| Architecture | [Flutter ↔ Rust WAV bridge](architecture/flutter-rust-bridge.md) | [Flutter ↔ Rust WAV bridge на русском](architecture/flutter-rust-bridge_RU.md) | Граница native facade и проверки WAV в памяти |
| Research | [Flutter Rust Bridge integration](research/flutter-rust-bridge-integration.md) | [Flutter Rust Bridge integration на русском](research/flutter-rust-bridge-integration_RU.md) | Структура generated code и команда повторной генерации |
| Research | [Acoustic-1 PHY sources](research/acoustic-1-phy-sources.md) | [Источники Acoustic-1 PHY](research/acoustic-1-phy-sources_RU.md) | Источники дизайна и явные receiver/FEC constraints |
| Research | [Acoustic-2 measurement sources](research/acoustic-2-measurement-sources.md) | [Источники измерений Acoustic-2](research/acoustic-2-measurement-sources_RU.md) | Ограничения controlled PCM transforms и timing acquisition |
| Research | [Device-acceptance sources](research/device-acceptance-sources.md) | [Источники device acceptance](research/device-acceptance-sources_RU.md) | Ограничения reproducible evidence, metadata и privacy |
| Research | [Live-audio adapter sources](research/live-audio-adapter-sources.md) | [Источники live-audio adapter](research/live-audio-adapter-sources_RU.md) | Ограничения session, permission, focus и lifecycle |
| Specification | [ADLP v1](../spec/protocol-v1.md) | [ADLP v1 на русском](../spec/protocol-v1_RU.md) | Нормативный wire object и WAV bootstrap carrier |
| Specification | [Acoustic-1](../spec/acoustic-1.md) | [Acoustic-1 на русском](../spec/acoustic-1_RU.md) | Экспериментальный B-FSK carrier и граница compatibility |
| Specification | [Acoustic-2](../spec/acoustic-2.md) | [Acoustic-2 на русском](../spec/acoustic-2_RU.md) | Экспериментальный controlled PCM measurement contract |
| Specification | [Live-audio adapter v1](../spec/live-audio-adapter-v1.md) | [Live-audio adapter v1 на русском](../spec/live-audio-adapter-v1_RU.md) | Typed unavailable-first contract для будущих routes |

## Правило поддержки перевода

В английском исходнике указывается `Last reviewed`. Русский sibling-файл указывает `Translation of` и `Last synced`. Если английский источник существенно меняется, перевод следует обновить в том же pull request; иначе создайте отдельный translation-only pull request с указанием revision исходника.

## Вклад в документацию

Исправления документации приветствуются. Примеры должны оставаться исполнимыми, планируемые возможности должны быть явно помечены, а платформа или маршрут не должны называться supported до выполнения критериев release. Правила репозитория описаны в [CONTRIBUTING.md](../CONTRIBUTING.md).
