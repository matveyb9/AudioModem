# ADLP WAV golden fixtures

`adlp-v1-text-balanced.wav` is a canonical WAV bootstrap fixture for deterministic regression coverage. It is generated only with the repository CLI and must not be replaced by an editor export or a manually modified file.

| Field | Canonical value |
| --- | --- |
| Generator | `cargo run -p adlp-cli -- encode-text` |
| Session ID | `1` |
| Callsign | `GOLDEN1` |
| Profile | `balanced` |
| UTF-8 text | `AudioModem ADLP golden fixture v1` |
| WAV shape | RIFF, mono, 16-bit PCM, 48 kHz |
| Size | `40,364` bytes |
| SHA-256 | `c13b9091604a6eaeb3bbb5570498ada82113c0c52e7cfb44fd9373c2cb001bf6` |

The Rust regression test both decodes this immutable fixture and regenerates it from the fixed ADLP object. A byte difference is therefore a deliberate codec compatibility change and must be reviewed together with an updated fixture, hash, protocol rationale, and release note.

## Acoustic-1 experimental carrier

`acoustic-1-v1-text-balanced.wav` is the canonical controlled-test vector for the experimental Acoustic-1 B-FSK carrier. It is generated only with the repository CLI and must not be replaced by an editor export or a manually modified file.

| Field | Canonical value |
| --- | --- |
| Generator | `cargo run -p adlp-cli -- encode-acoustic1-text` |
| Session ID | `1` |
| Callsign | `AC1GOLD` |
| Profile | `balanced` |
| UTF-8 text | `AudioModem Acoustic-1 golden fixture v1` |
| WAV shape | RIFF, mono, 16-bit PCM, 48 kHz |
| Size | `717,164` bytes |
| SHA-256 | `bbceae6d334284ede97ebe8113293fee53ea3e5e55822715802aa2a7819bc29b` |

The Acoustic-1 test decodes the fixture, confirms the fixed ADLP object and regenerates the complete WAV byte-for-byte. A fixture change is therefore a carrier compatibility change. It requires an RFC update, an updated hash, a documented measurement rationale and a release note; it does not by itself establish live acoustic interoperability.
