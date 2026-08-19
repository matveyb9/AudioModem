# Документация AudioModem

[English (canonical)](README.md) · **Русский перевод**

Этот каталог содержит читаемую техническую документацию AudioModem. Английские файлы являются каноническими. Русские переводы используют суффикс `_RU.md`, ссылаются на английский оригинал и носят информативный характер, пока RFC явно не установит иное.

> **Translation of:** [docs/README.md](README.md). **Last synced:** 2026-08-19.

| Раздел | Английский оригинал | Русский перевод | Область |
| --- | --- | --- | --- |
| Guides | [Quick start](guides/getting-started.md) | [Быстрый старт](guides/getting-started_RU.md) | Проверенный text-to-WAV round trip |
| Guides | [Audio routes](guides/audio-routes.md) | [Аудиомаршруты](guides/audio-routes_RU.md) | Маршруты доставки и границы scope |
| Reference | [Platform support](reference/platform-support.md) | [Поддержка платформ](reference/platform-support_RU.md) | Runners и supported features |
| Reference | [Transmission presets](reference/presets.md) | [Пресеты передачи](reference/presets_RU.md) | Profile identifiers и назначение |
| Operations | [Troubleshooting](troubleshooting.md) | [Диагностика](troubleshooting_RU.md) | Воспроизводимые наблюдения и отчёты |
| Project | [Roadmap](roadmap.md) | [Дорожная карта](roadmap_RU.md) | Проверенная работа и ближайшие milestones |
| Specification | [ADLP v1](../spec/protocol-v1.md) | [ADLP v1 на русском](../spec/protocol-v1_RU.md) | Нормативный wire object и WAV bootstrap carrier |

## Правило поддержки перевода

В английском исходнике указывается `Last reviewed`. Русский sibling-файл указывает `Translation of` и `Last synced`. Если английский источник существенно меняется, перевод следует обновить в том же pull request; иначе создайте отдельный translation-only pull request с указанием revision исходника.

## Вклад в документацию

Исправления документации приветствуются. Примеры должны оставаться исполнимыми, планируемые возможности должны быть явно помечены, а платформа или маршрут не должны называться supported до выполнения критериев release. Правила репозитория описаны в [CONTRIBUTING.md](../CONTRIBUTING.md).
