# Device-acceptance protocol research notes

**Last reviewed:** 2026-08-20 · **English (canonical)**

The future AudioModem device-acceptance protocol will curate an evidence bundle rather than treat one user report as a compatibility result. A report must distinguish a reproducible codec result from a separate physical-device observation and must not turn missing or private recordings into fabricated performance data.

| Source | Relevant finding | Design consequence |
| --- | --- | --- |
| Leipzig et al., *The role of metadata in reproducible computational research* | Metadata describe provenance and method context across inputs, tools, reports and pipelines; missing method details obstruct reproduction and evaluation.[1] | Require machine-readable report metadata for app revision, OS, device class, route settings, fixture identity, commands and outcome. |
| Research Data Alliance, *10 Things for Curating Reproducible and FAIR Research* | A reproducibility bundle needs data, code, outputs, documentation, provenance and automation sufficient to recreate a predefined outcome.[2] | Require a manifest, input/output hashes, reproducible command, report schema version and an explicit evidence availability state. |
| ARSC Technical Committee metadata study | Audio recording applications can have embedded-metadata persistence and integrity problems; reference files and test methods aid independent verification.[3] | Treat WAV bytes and SHA-256 as primary evidence; record capture/playback metadata in a sidecar report rather than rely on embedded audio tags. |

## Privacy and evidence policy

Raw recordings may contain speech, environmental audio or personal data. A report must therefore state one of `not_collected`, `private_available_on_request`, `public_redacted` or `public_unrestricted` instead of requiring upload. Any claim stronger than a reproducible local codec run requires declared device metadata, route settings, fixtures, run count and a reviewable evidence bundle.

## References

[1]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8441584/ "The role of metadata in reproducible computational research"
[2]: https://www.rd-alliance.org/wp-content/uploads/2022/04/1020Things20for20Curating20Reproducible20and20FAIR20Research20v1.1.pdf "10 Things for Curating Reproducible and FAIR Research"
[3]: https://www.weareavp.com/a-study-of-embedded-metadata-support-in-audio-recording-software/ "A Study of Embedded Metadata Support in Audio Recording Software"
