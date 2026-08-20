# Исследовательские заметки по протоколу device acceptance

[English (canonical)](device-acceptance-sources.md) · **Русский перевод**

> **Translation of:** [docs/research/device-acceptance-sources.md](device-acceptance-sources.md). **Last synced:** 2026-08-20.

Будущий AudioModem device-acceptance protocol будет курировать evidence bundle, а не считать один user report compatibility result. Report обязан отличать reproducible codec result от отдельного physical-device observation и не должен превращать отсутствующие или private recordings в вымышленные performance data.

| Источник | Значимое наблюдение | Следствие для дизайна |
| --- | --- | --- |
| Leipzig и соавт., *The role of metadata in reproducible computational research* | Metadata описывают provenance и method context для inputs, tools, reports и pipelines; отсутствие method details мешает reproduction и evaluation.[1] | Требовать machine-readable report metadata для app revision, OS, device class, route settings, fixture identity, commands и outcome. |
| Research Data Alliance, *10 Things for Curating Reproducible and FAIR Research* | Reproducibility bundle требует data, code, outputs, documentation, provenance и automation, достаточных для recreation predefined outcome.[2] | Требовать manifest, input/output hashes, reproducible command, report schema version и explicit evidence availability state. |
| ARSC Technical Committee metadata study | Audio recording applications могут иметь проблемы persistence и integrity embedded metadata; reference files и test methods помогают independent verification.[3] | Считать WAV bytes и SHA-256 primary evidence; capture/playback metadata хранить в sidecar report, а не полагаться на embedded audio tags. |

## Privacy и evidence policy

Raw recordings могут содержать speech, environmental audio или personal data. Поэтому report обязан указывать одно из `not_collected`, `private_available_on_request`, `public_redacted` или `public_unrestricted`, а не требовать upload. Любой claim сильнее reproducible local codec run требует declared device metadata, route settings, fixtures, run count и reviewable evidence bundle.

## Ссылки

[1]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8441584/ "The role of metadata in reproducible computational research"
[2]: https://www.rd-alliance.org/wp-content/uploads/2022/04/1020Things20for20Curating20Reproducible20and20FAIR20Research20v1.1.pdf "10 Things for Curating Reproducible and FAIR Research"
[3]: https://www.weareavp.com/a-study-of-embedded-metadata-support-in-audio-recording-software/ "A Study of Embedded Metadata Support in Audio Recording Software"
