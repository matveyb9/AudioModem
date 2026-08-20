# План реализации

[English (canonical)](implementation-plan.md) · **Русский перевод**

> **Translation of:** [docs/implementation-plan.md](implementation-plan.md). **Last synced:** 2026-08-21. Английский оригинал определяет implementation contract.

Этот план превращает публичную roadmap в порядок реализации. Он построен вокруг test gates: слой может использоваться следующим слоем только после выполнения явно указанных exit criteria. План не создаёт срок поставки, device-support claim или live-audio claim.

## Текущий baseline

| Слой | Что подтверждено сейчас | Чего намеренно нет сейчас |
| --- | --- | --- |
| ADLP Rust crate | Versioned text и file containers, transfer profiles, manifest validation и CRC-32C tests. | Encryption, identity authentication и UI logic. |
| Audio Rust crate | Deterministic 48 kHz PCM/WAV bootstrap, text/file golden fixtures, experimental Acoustic-1 и controlled Acoustic-2 measurement harness. | Streaming encode/decode API, microphone input, speaker output и physical-channel compatibility. |
| Flutter Rust facade | Typed text/file-to-WAV и WAV-to-text/file calls; native availability reporting. | Codec reimplementation и platform-route ownership. |
| Flutter workbench | Text и bounded file selection, callsign, preset, carrier, local WAV export/import, verified text/file receipts и local verified-payload save. | Persistent history, file-size policy сверх initial 8 KiB bridge limit, live capture/playback и hardware support claim. |
| Live-audio boundary | PCM v1 contract и unavailable implementation. | Permission requests, audio session/focus, plugin, real platform adapter или route result. |

> **Правило ownership:** Rust владеет каждым byte-level protocol и codec решением. Flutter владеет user intent, presentation, task state и platform-adapter selection. Bridge переводит только typed values; он не должен стать второй protocol implementation.

## Последовательность поставки

### Stage A — Зафиксировать reproducible core behavior

Следующая application work опирается на небольшой набор Rust-owned reproducible contracts. Existing text/WAV fixtures остаются reference. Перед добавлением нового object kind или carrier его Rust API, deterministic fixture, rejection cases и CLI behavior должны попасть вместе. Flutter application может mock'ировать этот API, пока contract готовится, но не должна самостоятельно выводить bytes, checksums или decoder success.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Current ADLP и WAV tests проходят. | Typed core/bridge contract для следующего supported object workflow, deterministic fixture и invalid-input cases. | Проходят `cargo fmt`, clippy, workspace tests и fixture regression tests. | Не подразумеваются live route или cross-platform feature. |

### Stage B — Построить Flutter transfer shell поверх fakes

Shell разрабатывается до зависимости от новой native capability. Она будет моделировать transfer как user-visible task со states preparation, verification, export/import, completion, rejection и cancellation. Fake bridge может выдавать deterministic results для widget tests; `UnavailableWavBootstrapBridge` и `UnavailableLiveAudioAdapter` остаются обязательными negative paths.

Сначала shell покрывает text и existing local WAV behavior. Её data model должна резервировать, но не притворяться реализующей, file-object payloads, route diagnostics и future receive queue. Callsign остаётся display metadata и не должен показываться как authentication.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Есть documented bridge contract и fake response fixture. | Testable transfer controller/state model; send и receive views; preset/callsign input; clear unavailable и rejection surfaces. | Widget tests покрывают success, cancellation, malformed input, bridge failure и unavailable route states. | Fake transfer не является encoded ADLP object и hardware test. |

### Stage C — Подключить shell к уже протестированному Rust facade

Когда shell state model стабилен, native integration связывает small bridge interface с Rust facade. Verification criterion — known fixture и decoded metadata, а не только successful button press. Web остаётся truthful unavailable build, пока не появится отдельно спроектированный web-compatible core.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Shell tests проходят с fake и unavailable dependencies. | Native integration tests для encode, decode, selected carrier, export/import и rejected input. | Проходят Flutter analysis/tests и native Linux build; decoded result совпадает с selected fixture. | Native fixture success не доказывает speaker-to-microphone delivery. |

### Stage D — Осмотрительно расширить data workflows

Text не должен молча использоваться как image или file. Первый bounded `File` payload workflow теперь существует в ADLP, Rust fixtures, CLI, thin bridge и Flutter local selection/receipt/save UI. Следующая работа — explicit size/memory policy сверх initial bridge limit и native fixture integration, сохраняющие deterministic local WAV reproduction до попытки physical route.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Text flow и integration gates пройдены. | File-object RFC, Rust validation/fixtures, thin bridge values, Flutter file-selection и receipt UI. | Rust и Flutter fixtures сохраняют name, declared media type, bytes и rejection behavior. | WAV-file transfer не доказывает live acoustic file transfer. |

### Stage E — Добавить один live-audio platform adapter

После стабилизации Flutter shell и PCM contract platform work начинается с одного route RFC. Первый selected design target — **Android API 26+ foreground playback/capture**, описанный в [Android live-audio adapter v1 RFC](../spec/android-live-audio-adapter-v1_RU.md). Он задаёт native APIs, session/permission policy, interruption behavior, default-route boundary, buffer/format checks, diagnostics и stop/dispose semantics. Adapter остаётся unavailable до review RFC и acceptance change; вне declared scope он останется unavailable.

| Entry condition | Work product | Exit gate | Explicit non-claim |
| --- | --- | --- | --- |
| Android route RFC, machine-checked acceptance extension и target build утверждены. | Один Android adapter, unit/integration tests и real privacy-preserving physical-route reports. | Adapter сообщает только declared availability; существует reviewed physical-route report для exact scope. | Одно observation не является broad compatibility, range, Bluetooth или radio claim. |

### Stage F — Публикация evidence, compatibility и releases

После repeated reviewed evidence compatibility documentation может описывать exact tested target, build, carrier, route и limitations. Release engineering начинается только когда supported scope имеет reproducible build и documented support policy. Trust и encryption остаются independent RFC track; они не добавляются как opportunistic UI toggle.

## Working rules

| Rule | Практическое следствие |
| --- | --- |
| Test the layer that owns behavior. | Rust tests устанавливают protocol/codec correctness; Flutter tests — user-flow и presentation correctness; device reports — только observed route behavior. |
| Preserve one-way dependencies. | Flutter вызывает bridge; bridge вызывает Rust; Rust не импортирует Flutter или platform UI concerns. |
| Keep unsupported paths visible. | Unavailable adapters возвращают reason и не инициализируют plugins и не запрашивают permissions. |
| Use fixtures as integration currency. | Каждый новый workflow даёт committed success fixture и meaningful rejection case до добавления UI success wording. |
| Make claims narrower than evidence. | Passing test, schema-valid report или одно device observation никогда не превращаются в generic support badge. |

## Ближайший порядок исполнения

Активный milestone — **Stage E Android route design review**. В repository теперь есть bilingual Android foreground RFC, research decision, unexecuted reporting template и validator extension, требующий exact v1 PCM, permission, focus, stop и privacy fields для future Android speaker-to-microphone measurements. Next implementation change может добавить native Android adapter только после review и merge этого design slice. Он должен начинаться unavailable вне Android API 26+ foreground scope и не может создавать physical-route claim без real reviewed observations.
