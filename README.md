# AudioModem

> **Experimental open-source audio data link.** Transfer text and files as sound through lossless WAV files today, then through speakers, microphones, audio cables, radio interfaces and OS-managed Bluetooth routes as the project matures.

**English (canonical)** · [Русский](README_RU.md)

AudioModem separates a versioned data object from the path that carries its PCM signal. The same ADLP object can be exported as WAV for a reproducible hand-off, sent over a future speaker-to-microphone path, connected to a line-level cable, or routed through external radio equipment. The repository contains a Rust protocol/core, a Flutter application surface and a public specification.

## Status

AudioModem is in the **bootstrap** stage. The verified path is text → ADLP v1 object → lossless WAV → ADLP v1 object → verified text. Live capture/playback, Bluetooth audio routing, radio interfaces, encryption, file payloads in the CLI and release artifacts are **not implemented**. See the [roadmap](docs/roadmap.md) for the intended order of work.

| Area | Current status | Read more |
| --- | --- | --- |
| ADLP v1 container | Implemented and tested in Rust | [Protocol](spec/protocol-v1.md) |
| Bootstrap WAV codec | Implemented for deterministic 48 kHz mono PCM WAV round trips | [Quick start](docs/guides/getting-started.md) |
| Flutter client | Cross-platform UI scaffold; no Rust bridge yet | [Platform support](docs/reference/platform-support.md) |
| Live acoustic modem | Designed, not implemented | [Audio routes](docs/guides/audio-routes.md) |
| Encryption and verified identity | Future RFC work | [Security](SECURITY.md) |

## Quick start: a reproducible WAV round trip

Install a stable Rust toolchain, clone this repository, then run the diagnostic CLI from the workspace root.

```bash
cargo run -p adlp-cli -- encode-text hello.wav N1 "Hello from AudioModem" reliable
cargo run -p adlp-cli -- decode hello.wav
```

The command writes a lossless mono 48 kHz, signed 16-bit PCM WAV file and decodes the same object. This bootstrap symbol mapper is deliberately simple; it is **not** a robust over-the-air modulation scheme. The [quick-start guide](docs/guides/getting-started.md) explains the guarantee and its limits.

## Documentation

| English (canonical) | Russian translation | Purpose |
| --- | --- | --- |
| [Documentation index](docs/README.md) | [Индекс документации](docs/README_RU.md) | Navigation and language policy |
| [Quick start](docs/guides/getting-started.md) | [Быстрый старт](docs/guides/getting-started_RU.md) | Reproducible WAV workflow |
| [Audio routes](docs/guides/audio-routes.md) | [Аудиомаршруты](docs/guides/audio-routes_RU.md) | WAV, live PCM, cable, radio and Bluetooth boundaries |
| [Protocol v1](spec/protocol-v1.md) | [Протокол v1](spec/protocol-v1_RU.md) | ADLP object and bootstrap WAV carrier |
| [Platform support](docs/reference/platform-support.md) | [Поддержка платформ](docs/reference/platform-support_RU.md) | Target runners and feature status |
| [Transmission presets](docs/reference/presets.md) | [Пресеты передачи](docs/reference/presets_RU.md) | Reliable, Balanced, Fast and Narrowband IDs |
| [Troubleshooting](docs/troubleshooting.md) | [Диагностика](docs/troubleshooting_RU.md) | Observable failures and useful reports |
| [Roadmap](docs/roadmap.md) | [Дорожная карта](docs/roadmap_RU.md) | Verified work versus planned work |

The English source is canonical for protocol compatibility, release commitments and implementation decisions. Russian documents are maintained translations; each Russian file links to its English counterpart and records the synchronization date.

## Repository map

```text
crates/                 Rust protocol, container and codec crates
apps/audio_modem/       Flutter application for Android, iOS, desktop and web runners
tools/adlp-cli/         Diagnostic CLI for ADLP/WAV workflows
spec/                   Versioned protocol specifications
docs/                   English-first contributor and technical documentation
site/                   Static GitHub Pages source
fixtures/               Small synthetic test assets only
.github/                Issue forms, ownership and automation
```

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Protocol, DSP and cryptographic changes begin with the RFC process described in [GOVERNANCE.md](GOVERNANCE.md). Use [SECURITY.md](SECURITY.md) for private security reports; do not publish vulnerabilities in an issue.

## License

Code is dual-licensed under **MIT OR Apache-2.0**. Documentation is **CC-BY-4.0** unless stated otherwise. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).
