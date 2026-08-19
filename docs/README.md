# AudioModem documentation

**English (canonical)** · [Русский](README_RU.md)

This directory holds the human-readable technical documentation for AudioModem. English files are canonical. Russian translations use the `_RU.md` suffix, link to their English source, and are informative unless an RFC explicitly says otherwise.

| Section | English | Russian | Scope |
| --- | --- | --- | --- |
| Guides | [Quick start](guides/getting-started.md) | [Быстрый старт](guides/getting-started_RU.md) | Verified text-to-WAV round trip |
| Guides | [Audio routes](guides/audio-routes.md) | [Аудиомаршруты](guides/audio-routes_RU.md) | Delivery routes and scope boundaries |
| Reference | [Platform support](reference/platform-support.md) | [Поддержка платформ](reference/platform-support_RU.md) | Runners versus supported features |
| Reference | [Transmission presets](reference/presets.md) | [Пресеты передачи](reference/presets_RU.md) | Profile identifiers and intent |
| Operations | [Troubleshooting](troubleshooting.md) | [Диагностика](troubleshooting_RU.md) | Reproducible observations and reports |
| Project | [Roadmap](roadmap.md) | [Дорожная карта](roadmap_RU.md) | Verified work and upcoming milestones |
| Specification | [ADLP v1](../spec/protocol-v1.md) | [ADLP v1 на русском](../spec/protocol-v1_RU.md) | Normative wire object and WAV bootstrap carrier |

## Translation convention

An English source document begins with `Last reviewed`. Its Russian sibling records both `Translation of` and `Last synced`. A translation should be updated in the same pull request when an English source changes materially; otherwise, open a translation-only pull request and identify the source revision.

## Documentation contribution

Documentation corrections are welcome. Please keep examples executable, label planned capabilities clearly, and do not describe a platform or route as supported until its release criteria are met. See [CONTRIBUTING.md](../CONTRIBUTING.md) for the repository workflow.
