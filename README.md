# AudioModem

> **Experimental open-source audio data modem.** Transfer text and files as sound through speakers, microphones, audio cables, radios, Bluetooth audio routes, or lossless WAV files.

AudioModem turns versioned transfer frames into PCM audio and back. The delivery route is interchangeable: the same protocol works with a speaker and microphone, a cable, a radio audio interface, an OS-managed Bluetooth route, or a WAV file. The project consists of a Rust core, a Flutter client for Android, iOS, Windows, macOS, Linux and Web, and a public protocol specification.

## Status

The repository is at the **bootstrap** stage. The first milestone is a reproducible WAV round trip: package a text or file, encode it, export lossless WAV, import it and verify the original object. Live audio, Bluetooth, radio routes, encryption and production compatibility claims are not implemented yet.

## Principles

| Principle | Meaning |
|---|---|
| Transport-independent | Audio delivery and the data-link protocol are separate. |
| Verifiable | Data is published only after frame checks and final object verification. |
| Observable | The app exposes route, profile, signal and failure states. |
| Interoperable | Protocol versions, PHY profiles and golden vectors are separate from app releases. |
| Honest about trust | A callsign is a display label, not identity proof. |

## Repository map

```text
crates/                 Rust protocol, core and DSP crates
apps/audio_modem/       Flutter application for all targets
tools/adlp-cli/         WAV and protocol diagnostic CLI
spec/                   Versioned specifications and golden vectors
docs/                   Contributor and technical documents
site/                   GitHub Pages documentation site
fixtures/               Small synthetic test assets only
.github/                Issue forms, ownership and automation
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Protocol, DSP and cryptographic changes use the RFC process in [GOVERNANCE.md](GOVERNANCE.md). Security reports follow [SECURITY.md](SECURITY.md).

## License

Code is dual-licensed under **MIT OR Apache-2.0**. Documentation is **CC-BY-4.0** unless stated otherwise. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).
