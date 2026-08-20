# Дорожная карта

[English (canonical)](roadmap.md) · **Русский перевод**

> **Translation of:** [docs/roadmap.md](roadmap.md). **Last synced:** 2026-08-21.

Эта дорожная карта описывает intended order, а не даты или гарантированные сроки. Она отделяет verified repository state от research и planned product capability.

| Milestone | Состояние | Результат |
| --- | --- | --- |
| GitHub-first bootstrap | Завершён | Public repository policy, issue forms, CI workflows, protected main и static-site workflow. |
| ADLP v1 и WAV reference | Завершён | Rust container, CRC-32C, deterministic PCM/WAV round trip, CLI и initial specification. |
| Flutter ↔ Rust bridge | Завершён | Native UI вызывает reviewed Rust ADLP/WAV encode/decode; web сообщает, что native codec недоступен. |
| Локальный WAV file workflow | Завершён | User-selected save/open dialogs экспортируют/импортируют проверенные WAV bytes; file-object UI остаётся future work. |
| File-object local WAV workflow | Экспериментальный bounded workflow | Существуют ADLP `File` constructor, bounded 8 KiB Rust facade, deterministic WAV fixture, CLI и Flutter local pick/receipt/save flow; physical route не включён. |
| Acoustic-1 | Экспериментальный controlled carrier | B-FSK framing, bounded synchronisation, Hamming(7,4), profile-driven symbols и golden vectors существуют для PCM/WAV tests; speaker-to-microphone claim отсутствует. |
| Acoustic-2 | Экспериментальный measurement harness | Вокруг Acoustic-1 существуют declared integer PCM transforms, bounded acquisition observables и golden measurement contract; device или channel metric claim отсутствует. |
| Device-acceptance infrastructure | Завершён reporting/tooling contract | Schema, validator, privacy-preserving intake template и decision gates готовят future evidence; physical-route observation или supported device claim отсутствуют. |
| Live-audio adapter contract | Завершён unavailable scaffold | Существуют typed PCM/lifecycle boundary и unavailable behavior tests; plugin, permission, capture, playback или physical route не включены. |
| Audio adapters | Планируется | Capture/playback, cable, Bluetooth и radio-interface adapters с per-platform acceptance tests. |
| Trust и encryption | Planned RFC | Key lifecycle, manual/QR exchange, authenticated encryption, verification UX и independent security review. |
| Release engineering | Планируется | Signed packages, compatibility matrix, changelog, SBOM/checksums и clear support policy. |

## Decision gates

Проект не должен заявлять live delivery, пока Acoustic-1 profile, route adapter и acceptance test не существуют вместе. Schema-valid device report устанавливает только format; support claim дополнительно требует reviewable physical-route evidence и опубликованного supported-route gate. Проект не должен заявлять encryption, пока reviewed RFC не определит key ownership, exchange, verification, recovery и failure behavior. Он не должен заявлять cross-platform support, пока target не получил reproducible release artifact и documented limits.

## Участие

Предложения, меняющие wire compatibility, profile interpretation, error correction или cryptographic behavior, должны начинаться с RFC по процессу из [GOVERNANCE.md](../GOVERNANCE.md). Небольшие documentation, test и UI changes могут использовать обычные issue и pull request.
