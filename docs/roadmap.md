# Roadmap

**Last reviewed:** 2026-08-20 · **English (canonical)** · [Русский](roadmap_RU.md)

This roadmap describes intended order, not dates or guaranteed delivery. It distinguishes verified repository state from research and planned product capability.

| Milestone | State | Outcome |
| --- | --- | --- |
| GitHub-first bootstrap | Completed | Public repository policy, issue forms, CI workflows, protected main and static-site workflow. |
| ADLP v1 and WAV reference | Completed | Rust container, CRC-32C, deterministic PCM/WAV round trip, CLI and initial specification. |
| Flutter ↔ Rust bridge | Completed | Native UI invokes reviewed Rust ADLP/WAV encode/decode; web reports the native codec unavailable. |
| Local WAV file workflow | Completed | User-selected save/open dialogs export/import verified WAV bytes; file-object payloads remain future work. |
| Acoustic-1 | Experimental controlled carrier | B-FSK framing, bounded synchronisation, Hamming(7,4), profile-driven symbols and golden vectors exist for PCM/WAV tests; no speaker-to-microphone claim. |
| Acoustic-2 | Experimental measurement harness | Declared integer PCM transforms, bounded acquisition observables and golden measurement contract exist around Acoustic-1; no device or channel metric claim. |
| Audio adapters | Planned | Capture/playback, cable, Bluetooth and radio-interface adapters with per-platform acceptance tests. |
| Trust and encryption | Planned RFC | Key lifecycle, manual/QR exchange, authenticated encryption, verification UX and independent security review. |
| Release engineering | Planned | Signed packages, compatibility matrix, changelog, SBOM/checksums and clear support policy. |

## Decision gates

The project should not declare live delivery before an Acoustic-1 profile, a route adapter and an acceptance test exist together. It should not declare encryption before a reviewed RFC defines key ownership, exchange, verification, recovery and failure behavior. It should not claim cross-platform support before a target has a reproducible release artifact and documented limits.

## Participation

Proposals that alter wire compatibility, profile interpretation, error correction or cryptographic behavior must start as an RFC under the process in [GOVERNANCE.md](../GOVERNANCE.md). Smaller documentation, test and UI changes can use an ordinary issue and pull request.
