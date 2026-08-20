# Протокол device acceptance

[English (canonical)](device-acceptance.md) · **Русский перевод**

> **Translation of:** [docs/operations/device-acceptance.md](device-acceptance.md). **Last synced:** 2026-08-21. Английский оригинал определяет contract implementation.

Этот protocol регулирует будущие evidence для live audio route. Он **не** делает supported ни платформу, ни устройство, ни кабель, ни Bluetooth path, ни radio interface, ни Acoustic-1/Acoustic-2 experiment. Один report — observation, ожидающее review, а не performance claim.

> Protocol курирует evidence bundle за claim: input artifact, method, environment, outputs и provenance. Structured metadata и provenance нужны для independent evaluation, тогда как raw audio опционален, поскольку может быть sensitive.[1] [2]

## Классы отчётов

| Report class | Что он устанавливает | Чего он не устанавливает |
| --- | --- | --- |
| `template` | В repository существует schema-valid, unexecuted reporting form. | Любое device measurement или support claim. |
| `codec_reproduction` | Named WAV fixture и command воспроизводят codec result. | Physical audio path. |
| `controlled_pcm` | Declared Acoustic-2 PCM transform дал specified codec-observable result. | Device, room, SNR, BER или live-route result. |
| `physical_route` | Reviewable run наблюдался через named physical route и settings. | Broad compatibility, range, reliability или статус “supported”. |

## Обязательные evidence измерения

Только record класса `measurement` может содержать physical-route evidence. Он обязан указывать app revision, operating system/version, route type, source и sink device classes, selected carrier/profile, fixture path и SHA-256, exact command/settings, run count и accepted/rejected totals. Report schema намеренно исключает callsigns, serial numbers, personal content и обязательную загрузку raw audio.

Sidecar JSON report является авторитетным для configuration metadata. WAV bytes и их SHA-256 — primary recording artifact, поскольку audio metadata может не сохраняться между recording applications.[3]

| Evidence field | Обязательное назначение | Privacy requirement |
| --- | --- | --- |
| App revision и command | Связывает behavior с reviewable implementation и invocation. | Никогда не включайте credentials или paths с personal identifiers. |
| Device class и optional public model | Отличает broad hardware category от device identity. | Не записывайте serial numbers, MAC addresses или account names. |
| Carrier, profile, fixture и SHA-256 | Фиксирует input и protocol interpretation. | Используйте public fixtures или только hash. |
| Run totals и outcome class | Делает success, rejection и inconclusive outcomes видимыми. | Не превращайте totals в BER/SNR/range без отдельной method. |
| Recording availability state | Сообщает, можно ли review raw evidence. | Используйте `not_collected`, `private_available_on_request`, `public_redacted` или `public_unrestricted`; не загружайте sensitive audio по умолчанию. |

## Процедура

Contributor начинает с committed fixture и clean app/CLI revision, записывает exact route settings, выполняет declared trial count и сохраняет output logs вместе с SHA-256 values. Report может быть отправлен, даже если все trials rejected или inconclusive. Он не должен скрывать эти outcomes, подменять fixture или описывать unexecuted plan как measurement.

Перед открытием compatibility issue проверьте JSON sidecar локально:

```bash
node tools/device-acceptance/validate-report.mjs \
  tools/device-acceptance/fixtures/report-template-v1.json
```

Committed fixture выше намеренно является **unexecuted template**, а не device result. Новый measurement sidecar создаётся только после получения реальных hardware observations.

## Android foreground v1 extension

[Android foreground live-audio adapter RFC](../../spec/android-live-audio-adapter-v1_RU.md) выбирает first experimental platform-route design. Он не включает route. Generic schema и validator теперь резервируют `adapter_observation` для будущего `measurement`, где route точно `speaker_microphone`, а source и sink platforms — оба `android`. Такой record обязан указать reviewed adapter contract, Android API level не ниже 26, playback/capture operation, requested и effective **48 kHz / mono / PCM16 LE** format, granted microphone permission, granted или delayed-then-granted focus, route-change observation, stop-without-auto-resume policy и discarded raw PCM.

Extension намеренно узкий. Он не разрешает unexecuted template включать device/evidence fields и не изменяет требования для остальных routes. Он отклоняет Android observation с mismatched effective format или любым value, предполагающим raw audio retention либо auto-resume.

Для procedure tester используйте [Android device-acceptance runbook](android-device-acceptance-runbook_RU.md). Он связывает contextual permission, focus, interruption, lifecycle и privacy observations с этой schema, не превращая procedure или valid JSON в route-support claim.

```bash
node tools/device-acceptance/validate-report.mjs \
  tools/device-acceptance/fixtures/android-speaker-microphone-template-v1.json
node tools/device-acceptance/test-validator.mjs
```

Android template остаётся unexecuted. В нём нет device, run, outcome, permission или route observation и его нельзя приводить как Android measurement.

## Decision gates

| Gate | Required evidence | Permitted label |
| --- | --- | --- |
| Schema gate | Report проходит repository validator. | Только `report format valid`. |
| Observation gate | Reviewed `physical_route` record имеет complete fields и не нарушает privacy. | `observed` с его exact scope. |
| Candidate-route gate | Доступны repeated real runs, declared device/route settings, fixture hashes, failures и maintainer review. | `experimental route candidate`. |
| Supported-route gate | Существуют separate adapter RFC, reproducible target build, route-specific acceptance tests, published compatibility note и maintainer approval. | `supported` только для documented scope. |

[Constrained live-audio adapter RFC](../../spec/live-audio-adapter-v1_RU.md) закрывает только contract gate unavailable implementation'ом. Он не включает route и не даёт physical-route evidence, platform implementation или tests, требуемые поздними gates. Schema сама по себе не устанавливает последние три gates. Она лишь не даёт принять incomplete evidence за measurement. Текущие статусы остаются в [границах audio routes](../guides/audio-routes_RU.md) и [platform matrix](../reference/platform-support_RU.md).

## Ссылки

[1]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8441584/ "The role of metadata in reproducible computational research"
[2]: https://www.rd-alliance.org/wp-content/uploads/2022/04/1020Things20for20Curating20Reproducible20and20FAIR20Research20v1.1.pdf "10 Things for Curating Reproducible and FAIR Research"
[3]: https://www.weareavp.com/a-study-of-embedded-metadata-support-in-audio-recording-software/ "A Study of Embedded Metadata Support in Audio Recording Software"
