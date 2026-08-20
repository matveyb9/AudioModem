# Implementation plan

**Status:** Maintainer execution plan · **Last reviewed:** 2026-08-21 · **English (canonical)** · [Русский](implementation-plan_RU.md)

This plan turns the public roadmap into an implementation order. It is deliberately test-gated: a layer may be used by the next layer only after its explicit exit criteria are satisfied. The plan does not create a delivery date, a device-support claim, or a live-audio claim.

## Current baseline

| Layer | Verified today | Deliberately absent today |
| --- | --- | --- |
| ADLP Rust crate | Versioned text and file containers, transfer profiles, manifest validation and CRC-32C tests. | Encryption, identity authentication and any UI logic. |
| Audio Rust crate | Deterministic 48 kHz PCM/WAV bootstrap, text/file golden fixtures, experimental Acoustic-1 and controlled Acoustic-2 measurement harness. | Streaming encode/decode API, microphone input, speaker output and physical-channel compatibility. |
| Flutter Rust facade | Typed text/file-to-WAV and WAV-to-text/file calls; native availability reporting. | Codec reimplementation and platform-route ownership. |
| Flutter workbench | Text and bounded file selection, callsign, preset, carrier, local WAV export/import, verified text/file receipts and local verified-payload save. | Persistent history, file-size policy beyond the initial 8 KiB bridge limit, live capture/playback and a hardware support claim. |
| Live-audio boundary | PCM v1 contract and unavailable implementation. | Permission requests, audio session/focus, a plugin, a real platform adapter or route result. |

> **Ownership rule:** Rust owns every byte-level protocol and codec decision. Flutter owns user intent, presentation, task state and platform-adapter selection. The bridge translates typed values only; it must not become a second protocol implementation.

## Delivery sequence

### Stage A — Freeze reproducible core behavior

The next application work relies on a small set of Rust-owned, reproducible contracts. Existing text/WAV fixtures remain the reference. Before adding a new object kind or carrier, its Rust API, deterministic fixture, rejection cases and CLI behavior must land together. The Flutter application may mock that API while the contract is being prepared, but it must not infer bytes, checksums or decoder success itself.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Current ADLP and WAV tests pass. | Typed core/bridge contract for the next supported object workflow, plus deterministic fixture and invalid-input cases. | `cargo fmt`, clippy, workspace tests and fixture regression tests pass. | No live route or cross-platform feature is implied. |

### Stage B — Build the Flutter transfer shell against fakes

The shell is developed before it depends on a new native capability. It will model a transfer as a user-visible task with preparation, verification, export/import, completion, rejection and cancellation states. A fake bridge can produce deterministic results for widget tests; `UnavailableWavBootstrapBridge` and `UnavailableLiveAudioAdapter` remain required negative paths.

The shell will first cover text and existing local WAV behavior. Its data model must reserve, but not pretend to implement, file-object payloads, route diagnostics and a future receive queue. Callsign stays display metadata and must not be presented as authentication.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| A documented bridge contract and fake response fixture exist. | Testable transfer controller/state model; send and receive views; preset/callsign input; clear unavailable and rejection surfaces. | Widget tests cover success, cancellation, malformed input, bridge failure and unavailable route states. | A fake transfer is not an encoded ADLP object and is not a hardware test. |

### Stage C — Connect the shell to the already tested Rust facade

When the shell's state model is stable, native integration binds its small bridge interface to the Rust facade. The verification criterion is a known fixture and decoded metadata, not merely a successful button press. Web remains a truthful unavailable build until a separately designed web-compatible core is available.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Shell tests pass against fake and unavailable dependencies. | Native integration tests for encode, decode, selected carrier, export/import and rejected input. | Flutter analysis/tests plus native Linux build succeed; decoded result matches the selected fixture. | Native fixture success does not prove speaker-to-microphone delivery. |

### Stage D — Extend data workflows deliberately

Text must not be silently overloaded to represent an image or file. The first bounded `File` payload workflow now exists in ADLP, Rust fixtures, CLI, the thin bridge and Flutter local selection/receipt/save UI. The next work is an explicit size/memory policy beyond the initial bridge limit and native fixture integration, preserving deterministic local WAV reproduction before any physical route is attempted.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Text flow and integration gates pass. | File-object RFC, Rust validation/fixtures, thin bridge values, Flutter file-selection and receipt UI. | Rust and Flutter fixtures preserve name, declared media type, bytes and rejection behavior. | WAV-file transfer does not demonstrate live acoustic file transfer. |

### Stage E — Add one live-audio platform adapter

After the Flutter shell and PCM contract are stable, platform work begins with one route RFC. The first selected design target is **Android API 26+ foreground playback/capture**, documented in the [Android live-audio adapter v1 RFC](../spec/android-live-audio-adapter-v1.md). It specifies native APIs, session/permission policy, interruption behavior, default-route boundary, buffer/format checks, diagnostics and stop/dispose semantics. The adapter remains unavailable until the RFC and acceptance change receive review; it will remain unavailable outside its declared scope.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Android route RFC, machine-checked acceptance extension and target build are approved. | One Android adapter, unit/integration tests and real privacy-preserving physical-route reports. | The adapter reports only its declared availability; a reviewed physical-route report exists for the exact scope. | One observation is not a broad compatibility, range, Bluetooth or radio claim. |

### Stage F — Publish evidence, compatibility and releases

After repeated reviewed evidence, compatibility documentation may describe the exact tested target, build, carrier, route and limitations. Release engineering follows only when supported scope has a reproducible build and a documented support policy. Trust and encryption remain an independent RFC track; they are not added as an opportunistic UI toggle.

## Working rules

| Rule | Practical consequence |
| --- | --- |
| Test the layer that owns the behavior. | Rust tests establish protocol/codec correctness; Flutter tests establish user-flow and presentation correctness; device reports establish only observed route behavior. |
| Preserve one-way dependencies. | Flutter calls the bridge; the bridge calls Rust; Rust does not import Flutter or platform UI concerns. |
| Keep unsupported paths visible. | Unavailable adapters return a reason and do not initialize plugins or request permissions. |
| Use fixtures as integration currency. | Every new workflow supplies a committed success fixture and a meaningful rejection case before UI success wording is added. |
| Make claims narrower than evidence. | A passing test, schema-valid report or one device observation never becomes a generic support badge. |

## Immediate execution order

The active milestone is **Stage E Android route design review**. The repository now has a bilingual Android foreground RFC, research decision, unexecuted reporting template and validator extension that requires exact v1 PCM, permission, focus, stop and privacy fields for future Android speaker-to-microphone measurements. The next implementation change may add a native Android adapter only after this design slice is reviewed and merged. It must begin unavailable outside Android API 26+ foreground scope and must not create a physical-route claim without real reviewed observations.
