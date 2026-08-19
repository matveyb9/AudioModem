# Дорожная карта

[English (canonical)](roadmap.md) · **Русский перевод**

> **Translation of:** [docs/roadmap.md](roadmap.md). **Last synced:** 2026-08-19.

Эта дорожная карта описывает intended order, а не даты или гарантированные сроки. Она отделяет verified repository state от research и planned product capability.

| Milestone | Состояние | Результат |
| --- | --- | --- |
| GitHub-first bootstrap | Завершён | Public repository policy, issue forms, CI workflows, protected main и static-site workflow. |
| ADLP v1 и WAV reference | Завершён | Rust container, CRC-32C, deterministic PCM/WAV round trip, CLI и initial specification. |
| Flutter ↔ Rust bridge | Следующий | Flutter UI вызывает реальные ADLP/WAV encode и decode operations через reviewed bridge. |
| File object workflow | Планируется | Выбор файла, сохранение MIME/name metadata, encode/decode и integrity verification. |
| Acoustic-1 | Планируется | Framing, synchronization, FEC, profile behavior, measurements и golden vectors для speaker-to-microphone. |
| Audio adapters | Планируется | Capture/playback, cable, Bluetooth и radio-interface adapters с per-platform acceptance tests. |
| Trust и encryption | Planned RFC | Key lifecycle, manual/QR exchange, authenticated encryption, verification UX и independent security review. |
| Release engineering | Планируется | Signed packages, compatibility matrix, changelog, SBOM/checksums и clear support policy. |

## Decision gates

Проект не должен заявлять live delivery, пока Acoustic-1 profile, route adapter и acceptance test не существуют вместе. Он не должен заявлять encryption, пока reviewed RFC не определит key ownership, exchange, verification, recovery и failure behavior. Он не должен заявлять cross-platform support, пока target не получил reproducible release artifact и documented limits.

## Участие

Предложения, меняющие wire compatibility, profile interpretation, error correction или cryptographic behavior, должны начинаться с RFC по процессу из [GOVERNANCE.md](../GOVERNANCE.md). Небольшие documentation, test и UI changes могут использовать обычные issue и pull request.
