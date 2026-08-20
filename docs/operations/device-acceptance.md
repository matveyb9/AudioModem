# Device-acceptance protocol

**Status:** Experimental operations contract · **Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](device-acceptance_RU.md)

This protocol governs future evidence for a live audio route. It does **not** make any platform, device, cable, Bluetooth path, radio interface or Acoustic-1/Acoustic-2 experiment supported. A single report is an observation awaiting review; it is not a performance claim.

> The protocol curates the evidence bundle behind a claim: input artifact, method, environment, outputs and provenance. Structured metadata and provenance are required for independent evaluation, while raw audio is optional because it may be sensitive.[1] [2]

## Report classes

| Report class | What it establishes | What it does not establish |
| --- | --- | --- |
| `template` | The repository has a schema-valid, unexecuted reporting form. | Any device measurement or support claim. |
| `codec_reproduction` | A named WAV fixture and command reproduce a codec result. | A physical audio path. |
| `controlled_pcm` | A declared Acoustic-2 PCM transform produced its specified codec-observable result. | A device, room, SNR, BER or live-route result. |
| `physical_route` | A reviewable run was observed over the named physical route and settings. | Broad compatibility, range, reliability or “supported” status. |

## Required measurement evidence

Only a `measurement` record can contain physical-route evidence. It must identify the app revision, operating system/version, route type, source and sink device classes, selected carrier/profile, fixture path and SHA-256, exact command/settings, run count and accepted/rejected totals. The report schema deliberately excludes callsigns, serial numbers, personal content and raw-audio upload requirements.

The sidecar JSON report is authoritative for configuration metadata. The WAV bytes and their SHA-256 are the primary recording artifact because audio metadata can fail to persist across recording applications.[3]

| Evidence field | Required purpose | Privacy requirement |
| --- | --- | --- |
| App revision and command | Binds behavior to a reviewable implementation and invocation. | Never include credentials or paths containing personal identifiers. |
| Device class and optional public model | Distinguishes broad hardware category from device identity. | Do not record serial numbers, MAC addresses or account names. |
| Carrier, profile, fixture and SHA-256 | Pins the input and protocol interpretation. | Use public fixtures or a hash only. |
| Run totals and outcome class | Makes success, rejection and inconclusive outcomes visible. | Do not convert totals into BER/SNR/range without a dedicated method. |
| Recording availability state | States whether raw evidence can be reviewed. | Use `not_collected`, `private_available_on_request`, `public_redacted` or `public_unrestricted`; never upload sensitive audio by default. |

## Procedure

The contributor starts from a committed fixture and a clean app/CLI revision, records the exact route settings, runs the declared trial count, and preserves output logs plus SHA-256 values. A report may be submitted even when every trial is rejected or inconclusive. It must not omit those outcomes, substitute another fixture, or describe an unexecuted plan as a measurement.

Before opening a compatibility issue, validate the JSON sidecar locally:

```bash
node tools/device-acceptance/validate-report.mjs \
  tools/device-acceptance/fixtures/report-template-v1.json
```

The committed fixture above is intentionally an **unexecuted template**, not a device result. A contributor creates a new measurement sidecar only after obtaining real hardware observations.

## Decision gates

| Gate | Required evidence | Permitted label |
| --- | --- | --- |
| Schema gate | Report passes repository validator. | `report format valid` only. |
| Observation gate | A reviewed `physical_route` record has complete fields and no privacy violation. | `observed`, with its exact scope. |
| Candidate-route gate | Repeated real runs, declared device/route settings, fixture hashes, failures and a maintainer review are available. | `experimental route candidate`. |
| Supported-route gate | A separate adapter RFC, reproducible target build, route-specific acceptance tests, published compatibility note and maintainer approval all exist. | `supported` for only the documented scope. |

The [constrained live-audio adapter RFC](../../spec/live-audio-adapter-v1.md) closes only the contract gate with an unavailable implementation. It neither enables a route nor supplies the physical-route evidence, platform implementation or tests required by the later gates. The schema cannot establish the last three gates by itself. It only prevents incomplete evidence from being mistaken for a measurement. The existing [audio-route boundaries](../guides/audio-routes.md) and [platform matrix](../reference/platform-support.md) remain authoritative for current support status.

## References

[1]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8441584/ "The role of metadata in reproducible computational research"
[2]: https://www.rd-alliance.org/wp-content/uploads/2022/04/1020Things20for20Curating20Reproducible20and20FAIR20Research20v1.1.pdf "10 Things for Curating Reproducible and FAIR Research"
[3]: https://www.weareavp.com/a-study-of-embedded-metadata-support-in-audio-recording-software/ "A Study of Embedded Metadata Support in Audio Recording Software"
